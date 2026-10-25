//
//  PhoneWorkoutStarter.swift
//  Kraftli Timers
//
//  Starts an iPhone-initiated workout through the ADR-006 handshake: ask the Watch
//  to own it, and run it on the iPhone if the Watch doesn't answer in time.
//
//  ## The handshake (ADR-006 §4)
//  1. No Watch (not paired, app not installed) → the iPhone owns the workout at once.
//  2. Otherwise the iPhone sends a `StartRequest`, launches the Watch app via
//     `startWatchApp(toHandle:)` and follows the workout as a viewer. The UI shows
//     "Starting on Watch…" while `TimerSessionController.isAwaitingOwner` is true.
//  3. The Watch answers with revision 1 of the workout → the countdown begins.
//  4. If the launch fails or no snapshot arrives within `handshakeTimeout`, the iPhone
//     takes over as owner with the same `workoutID`. Its snapshot replaces the request
//     in the application context, so a Watch that starts late sees `owner: .phone`
//     and yields.
//

import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class PhoneWorkoutStarter {
    /// How long the iPhone waits for the Watch's first snapshot (decision 2026-10-25).
    static let handshakeTimeout: Duration = .seconds(5)

    /// When the iPhone last took over a workout because the Watch didn't answer.
    /// The UI shows "Watch not available — running on iPhone" when this changes.
    private(set) var lastFallbackDate: Date?

    @ObservationIgnored private let controller: TimerSessionController
    @ObservationIgnored private let isWatchAppAvailable: () -> Bool
    @ObservationIgnored private let launchWatchApp: (TimerConfig) async throws -> Void
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let schedulesTimeout: Bool
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var config: TimerConfig?

    /// The running Watch launch, exposed so tests can await its outcome.
    @ObservationIgnored private(set) var launchTask: Task<Void, Never>?

    /// - Parameters:
    ///   - controller: The app's timer session.
    ///   - isWatchAppAvailable: Whether a paired Watch has the app installed.
    ///   - launchWatchApp: Opens the Watch app with a HealthKit workout configuration for the timer.
    ///   - now: Wall-clock source. Injectable so tests can drive time deterministically.
    ///   - schedulesTimeout: Whether to schedule the handshake timeout. Tests turn it off
    ///     and call `handshakeTimedOut()` directly.
    init(
        controller: TimerSessionController,
        isWatchAppAvailable: @escaping () -> Bool,
        launchWatchApp: @escaping (TimerConfig) async throws -> Void,
        now: @escaping () -> Date = { Date() },
        schedulesTimeout: Bool = true
    ) {
        self.controller = controller
        self.isWatchAppAvailable = isWatchAppAvailable
        self.launchWatchApp = launchWatchApp
        self.now = now
        self.schedulesTimeout = schedulesTimeout
    }

    /// Starts a workout, on the Watch if possible.
    func start(workoutID: UUID, config: TimerConfig) {
        cancel()
        self.config = config

        guard isWatchAppAvailable() else {
            Logger.timerSync.info("No Watch app available; running workout on iPhone")
            controller.startAsOwner(phoneOwnedState(workoutID: workoutID, config: config))
            return
        }

        controller.requestStart(StartRequest(workoutID: workoutID, config: config, requestedAt: now()))
        launchTask = Task { [weak self, launchWatchApp] in
            do {
                try await launchWatchApp(config)
            } catch {
                Logger.healthKit.error("Failed to start workout on Watch: \(error.localizedDescription)")
                self?.takeOverIfStillWaiting(for: workoutID)
            }
        }
        if schedulesTimeout {
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.handshakeTimeout)
                guard !Task.isCancelled else { return }
                self?.takeOverIfStillWaiting(for: workoutID)
            }
        }
    }

    /// Stops waiting for the Watch, e.g. when the timer screen is dismissed.
    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        launchTask?.cancel()
        launchTask = nil
    }

    /// The handshake timeout fired. Normally scheduled by `start`; exposed for tests.
    func handshakeTimedOut() {
        guard let workoutID = controller.workoutID else { return }
        takeOverIfStillWaiting(for: workoutID)
    }

    // MARK: - Private

    private func takeOverIfStillWaiting(for workoutID: UUID) {
        guard controller.isAwaitingOwner, controller.workoutID == workoutID, let config else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        Logger.timerSync.info("Watch didn't confirm workout \(workoutID); running it on iPhone")
        controller.startAsOwner(phoneOwnedState(workoutID: workoutID, config: config))
        lastFallbackDate = now()
    }

    private func phoneOwnedState(workoutID: UUID, config: TimerConfig) -> TimerState {
        TimerState(workoutID: workoutID, owner: .phone, config: config, now: now())
    }
}

// MARK: - Previews

#if DEBUG
extension View {
    /// Provides an iPhone-only timer session for previews (no Watch, no channels).
    func previewTimerSession() -> some View {
        let controller = TimerSessionController(transport: CompositeTimerSyncTransport(transports: []))
        let starter = PhoneWorkoutStarter(
            controller: controller,
            isWatchAppAvailable: { false },
            launchWatchApp: { _ in }
        )
        return environment(controller).environment(starter)
    }
}
#endif
