//
//  WatchWorkoutStarter.swift
//  Kraftli Timers
//
//  The Watch's half of the start handshake (ADR-006 §4), plus Watch-started workouts.
//  Runs on the Watch only. It lives in the shared folder, and HealthKit and the
//  keep-alive session are injected as closures, so the handshake can be unit-tested
//  next to the iPhone's side over the same fake link.
//
//  ## iPhone-started workout
//  1. A `StartRequest` arrives (WatchConnectivity, often as the application context
//     read on a cold launch). The Watch follows the workout as a viewer, which makes
//     the UI show "Starting…", and starts its HealthKit session.
//  2. `handle(_ workoutConfiguration:)` (from `startWatchApp`) asks for a session
//     too. Both entry points share one session start, whichever comes first.
//  3. Session running → the Watch takes ownership: revision 1 with `startDate = now + 3 s`.
//  4. If an iPhone-owned snapshot for the workout shows up instead (the iPhone timed out
//     and took over), the Watch yields: it discards its session without saving and stays
//     a viewer, kept on screen by a keep-alive session.
//
//  ## Watch-started workout
//  The Watch owns it from the first moment and starts its session alongside.
//

import Foundation
import os

@Observable
@MainActor
final class WatchWorkoutStarter {
    /// A start request older than this is ignored: the iPhone has long since run the
    /// workout itself (its handshake timeout is 5 s), and a request read from a persisted
    /// context on a later launch must not start a stale workout.
    static let maxRequestAge: TimeInterval = 10

    /// How long the Watch waits to either own or follow a requested workout before
    /// giving up and closing its screen.
    static let watchdogTimeout: Duration = .seconds(10)

    /// A session start this recent is shared by the request and `handle(_ workoutConfiguration:)`.
    static let sessionReuseWindow: TimeInterval = 15

    /// An iPhone-started workout the UI should present. Cleared with `requestPresented()`.
    private(set) var requestedWorkout: StartRequest?

    @ObservationIgnored private let controller: TimerSessionController
    @ObservationIgnored private let startHealthSession: (_ timerKindRaw: String) async throws -> Void
    @ObservationIgnored private let discardHealthSession: () -> Void
    @ObservationIgnored private let startKeepAlive: () -> Void
    @ObservationIgnored private let endKeepAlive: () -> Void
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let schedulesWatchdog: Bool

    @ObservationIgnored private var sessionStart: Task<Bool, Never>?
    @ObservationIgnored private var sessionStartedAt: Date?
    @ObservationIgnored private var watchdogTask: Task<Void, Never>?
    @ObservationIgnored private var yieldedWorkoutID: UUID?

    /// The HealthKit session start for the current request, exposed so tests can await it.
    @ObservationIgnored private(set) var ownershipTask: Task<Void, Never>?

    /// - Parameters:
    ///   - controller: The Watch's timer session.
    ///   - transport: Its transport, whose start requests this starter handles.
    ///   - startHealthSession: Starts (and mirrors) a HealthKit workout session.
    ///   - discardHealthSession: Ends the current session without saving it.
    ///   - startKeepAlive / endKeepAlive: Keep the app on screen without a HealthKit session.
    ///   - now: Wall-clock source. Injectable so tests can drive time deterministically.
    ///   - schedulesWatchdog: Tests turn it off and call `watchdogFired()` directly.
    init(
        controller: TimerSessionController,
        transport: CompositeTimerSyncTransport,
        startHealthSession: @escaping (_ timerKindRaw: String) async throws -> Void,
        discardHealthSession: @escaping () -> Void,
        startKeepAlive: @escaping () -> Void = {},
        endKeepAlive: @escaping () -> Void = {},
        now: @escaping () -> Date = { Date() },
        schedulesWatchdog: Bool = true
    ) {
        self.controller = controller
        self.startHealthSession = startHealthSession
        self.discardHealthSession = discardHealthSession
        self.startKeepAlive = startKeepAlive
        self.endKeepAlive = endKeepAlive
        self.now = now
        self.schedulesWatchdog = schedulesWatchdog
        transport.onStartRequest = { [weak self] request in self?.receive(request) }
        controller.onConfirmedStateChange = { [weak self] state in self?.confirmed(state) }
    }

    // MARK: - Entry Points

    /// Handles the iPhone's request to start and own a workout.
    func receive(_ request: StartRequest) {
        let age = now().timeIntervalSince(request.requestedAt)
        guard age <= Self.maxRequestAge else {
            Logger.timerSync.info("Ignoring start request \(request.workoutID) from \(Int(age)) s ago")
            return
        }
        guard controller.workoutID != request.workoutID else { return }

        Logger.timerSync.info("Start request \(request.workoutID) received; starting HealthKit session")
        controller.startAsViewer(workoutID: request.workoutID)
        yieldedWorkoutID = nil
        requestedWorkout = request
        scheduleWatchdog(for: request.workoutID)

        let session = ensureHealthSession { [startHealthSession] in
            try await startHealthSession(request.config.timerKindRaw)
        }
        ownershipTask = Task { [weak self] in
            let started = await session.value
            self?.healthSessionFinishedStarting(started, for: request)
        }
    }

    /// Handles `handle(_ workoutConfiguration:)`: the iPhone launched the app for a workout.
    /// Shares the session start with a start request that arrived (or arrives) alongside.
    func watchAppLaunched(startSession: @escaping () async throws -> Void) {
        _ = ensureHealthSession(startSession)
    }

    /// Starts a workout from the Watch itself: owned here from the first moment.
    func startOnWatch(workoutID: UUID, config: TimerConfig) {
        cancelWatchdog()
        yieldedWorkoutID = nil
        controller.startAsOwner(TimerState(workoutID: workoutID, owner: .watch, config: config, now: now()))
        sessionStart = nil
        _ = ensureHealthSession { [startHealthSession] in
            try await startHealthSession(config.timerKindRaw)
        }
    }

    /// The UI has presented `requestedWorkout`.
    func requestPresented() {
        requestedWorkout = nil
    }

    /// The workout's screen closed: stop following or owning it. The view ends or saves
    /// the HealthKit session itself before calling this.
    func workoutEnded() {
        cancelWatchdog()
        ownershipTask = nil
        sessionStart = nil
        sessionStartedAt = nil
        endKeepAlive()
        controller.onRenderedStateChange = nil
        controller.end()
    }

    /// Gives up on a requested workout nobody confirmed. Normally scheduled; exposed for tests.
    func watchdogFired() {
        guard controller.isAwaitingOwner, let workoutID = controller.workoutID else { return }
        Logger.timerSync.warning("No owner for workout \(workoutID) after the watchdog timeout; closing it")
        discardHealthSession()
        workoutEnded()
    }

    // MARK: - Private

    /// Returns the shared session start, beginning one if none is recent enough.
    private func ensureHealthSession(_ start: @escaping () async throws -> Void) -> Task<Bool, Never> {
        if let sessionStart, let sessionStartedAt,
           now().timeIntervalSince(sessionStartedAt) < Self.sessionReuseWindow {
            return sessionStart
        }
        let task = Task<Bool, Never> {
            do {
                try await start()
                return true
            } catch {
                Logger.workoutSession.error("Failed to start workout session: \(error.localizedDescription)")
                return false
            }
        }
        sessionStart = task
        sessionStartedAt = now()
        return task
    }

    private func healthSessionFinishedStarting(_ started: Bool, for request: StartRequest) {
        // Ended, or replaced by a newer request, meanwhile.
        guard controller.workoutID == request.workoutID else { return }

        guard controller.isAwaitingOwner else {
            // The iPhone's snapshot arrived first: it owns the workout, so this session must go.
            if started, yieldedWorkoutID == request.workoutID {
                discardHealthSession()
            }
            return
        }
        guard started else {
            // Without a session the Watch can't own the workout. The iPhone times out and
            // runs it; this device then follows (or the watchdog closes the screen).
            return
        }
        cancelWatchdog()
        Logger.timerSync.info("Taking ownership of workout \(request.workoutID)")
        controller.startAsOwner(TimerState(workoutID: request.workoutID, owner: .watch, config: request.config, now: now()))
    }

    /// The yield rule: once the iPhone owns this workout, drop the HealthKit session.
    private func confirmed(_ state: TimerState) {
        guard state.owner == .phone, yieldedWorkoutID != state.workoutID else { return }
        Logger.timerSync.info("iPhone owns workout \(state.workoutID); discarding the Watch's session")
        yieldedWorkoutID = state.workoutID
        cancelWatchdog()
        discardHealthSession()
        sessionStart = nil
        sessionStartedAt = nil
        startKeepAlive()
    }

    private func scheduleWatchdog(for workoutID: UUID) {
        cancelWatchdog()
        guard schedulesWatchdog else { return }
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: Self.watchdogTimeout)
            guard !Task.isCancelled, self?.controller.workoutID == workoutID else { return }
            self?.watchdogFired()
        }
    }

    private func cancelWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }
}
