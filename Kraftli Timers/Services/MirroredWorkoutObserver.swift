//
//  MirroredWorkoutObserver.swift
//  Kraftli Timers
//
//  Observes the mirrored HKWorkoutSession received from Apple Watch.
//
//  When Watch starts a workout and mirrors it to iPhone, Apple delivers
//  an HKWorkoutSession via HKHealthStore.workoutSessionMirroringStartHandler.
//  This class sets itself as that session's delegate so iPhone can observe
//  state changes (running, paused, ended) that originate on Watch — even
//  when WCSession.sendMessage() fails due to connectivity drops.
//
//  iPhone can also call pause()/resume() on the mirrored session to propagate
//  state changes *to* Watch via HealthKit's built-in reliable transport.
//

#if os(iOS)
import Foundation
import HealthKit
import os

/// Observes and controls the mirrored HKWorkoutSession from Apple Watch.
///
/// ## How HKWorkoutSession Mirroring Works
/// When Watch calls `startMirroringToCompanionDevice()`, Apple creates a
/// paired session on iPhone. State changes on either side automatically
/// propagate to the other via HealthKit — no WCSession needed. This makes
/// it a reliable fallback when Bluetooth briefly drops.
///
/// ## Usage
/// 1. Call `setSession(_:)` when the mirroring handler delivers a session
/// 2. Observe `sessionState` in SwiftUI views via `@Environment`
/// 3. Call `pause()` / `resume()` to propagate local actions to Watch
@Observable @MainActor
final class MirroredWorkoutObserver: NSObject {
    // MARK: - Public State

    /// Current state of the mirrored workout session.
    private(set) var sessionState: SessionState = .idle

    enum SessionState: Equatable {
        case idle
        case running
        case paused
        case ended
    }

    // MARK: - Private State

    private var session: HKWorkoutSession?

    // MARK: - Session Management

    /// Store the mirrored session and start observing its state changes.
    ///
    /// Called from the mirroring handler in `Kraftli_TimersApp` when Watch
    /// mirrors a workout session to iPhone.
    func setSession(_ session: HKWorkoutSession) {
        self.session = session
        session.delegate = self

        // Sync initial state from the session we just received
        switch session.state {
        case .running:
            sessionState = .running
        case .paused:
            sessionState = .paused
        case .ended, .stopped:
            sessionState = .ended
        default:
            sessionState = .idle
        }

        Logger.workoutSession.info("Mirrored session stored, initial state: \(String(describing: session.state))")
    }

    /// Clear the stored session (e.g., when workout ends).
    func clearSession() {
        session = nil
        sessionState = .idle
        Logger.workoutSession.info("Mirrored session cleared")
    }

    // MARK: - Control (iPhone → Watch via mirroring)

    /// Pause the mirrored session. Propagates to Watch via HealthKit.
    ///
    /// No-op if no mirrored session exists (e.g., standalone iPhone workout).
    func pause() {
        session?.pause()
    }

    /// Resume the mirrored session. Propagates to Watch via HealthKit.
    ///
    /// No-op if no mirrored session exists.
    func resume() {
        session?.resume()
    }
}

// MARK: - HKWorkoutSessionDelegate

extension MirroredWorkoutObserver: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                sessionState = .running
            case .paused:
                sessionState = .paused
            case .ended, .stopped:
                sessionState = .ended
            default:
                break
            }
            Logger.workoutSession.info("Mirrored session state: \(String(describing: fromState)) → \(String(describing: toState))")
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            Logger.workoutSession.error("Mirrored session failed: \(error.localizedDescription)")
            sessionState = .ended
        }
    }
}
#endif
