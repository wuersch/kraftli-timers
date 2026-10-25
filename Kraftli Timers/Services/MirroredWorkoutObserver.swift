//
//  MirroredWorkoutObserver.swift
//  Kraftli Timers
//
//  Holds the mirrored HKWorkoutSession received from Apple Watch, for the
//  HealthKit timer sync channel (ADR-006).
//
//  When Watch starts a workout and mirrors it to iPhone, Apple delivers
//  an HKWorkoutSession via HKHealthStore.workoutSessionMirroringStartHandler.
//  This class keeps that session so `HealthKitTimerSyncTransport` can send data
//  over it, and forwards the data the Watch sends back.
//
//  The session's own state (running, paused, ended) no longer drives the timer:
//  the Watch's HealthKit pause/resume is a consequence of the timer state, not a
//  control channel.
//

#if os(iOS)
import Foundation
import HealthKit
import os

/// Holds the mirrored HKWorkoutSession from Apple Watch for the HealthKit data channel.
@MainActor
final class MirroredWorkoutObserver: NSObject {
    /// The mirrored session, for sending data over its HealthKit channel
    /// (`HealthKitTimerSyncTransport`).
    var currentSession: HKWorkoutSession? {
        session
    }

    /// Called on the main actor with data the Watch sent over the mirrored session.
    var onRemoteData: (([Data]) -> Void)?

    /// Called when a (new) mirrored session is stored, e.g. after a reconnect.
    var onSessionConnected: (() -> Void)?

    private var session: HKWorkoutSession?

    // MARK: - Session Management

    /// Store the mirrored session and receive its data.
    ///
    /// Called from the mirroring handler in `Kraftli_TimersApp` when Watch
    /// mirrors a workout session to iPhone.
    func setSession(_ session: HKWorkoutSession) {
        // Detach the previous session's delegate so its late callbacks (e.g. a
        // trailing didDisconnect in a back-to-back A→B workout flow) can't
        // clear away the session we're about to store.
        self.session?.delegate = nil
        self.session = session
        session.delegate = self
        Logger.workoutSession.info("Mirrored session stored, state: \(String(describing: session.state))")
        onSessionConnected?()
    }

    /// Clear the stored session (e.g., when the Watch disconnects).
    func clearSession() {
        session?.delegate = nil
        session = nil
        Logger.workoutSession.info("Mirrored session cleared")
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
            // Logged for diagnostics only; the timer follows `TimerState`, not the session.
            Logger.workoutSession.info("Mirrored session state: \(String(describing: fromState)) → \(String(describing: toState))")
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        let description = error.localizedDescription
        Task { @MainActor in
            Logger.workoutSession.error("Mirrored session failed: \(description)")
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor in
            // Data from a replaced session belongs to a previous workout.
            guard workoutSession === self.session else { return }
            self.onRemoteData?(data)
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: (any Error)?
    ) {
        Task { @MainActor in
            // A trailing disconnect from workout A must not clear workout B's session,
            // which would cut B off from the HealthKit data channel.
            guard workoutSession === self.session else {
                Logger.workoutSession.info("Ignoring disconnect from stale mirrored session")
                return
            }
            if let error {
                Logger.workoutSession.error("Mirrored session disconnected with error: \(error.localizedDescription)")
            } else {
                Logger.workoutSession.info("Mirrored session disconnected")
            }
            clearSession()
        }
    }
}
#endif
