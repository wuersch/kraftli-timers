//
//  HealthKitTimerSyncTransport.swift
//  Kraftli Timers
//
//  Carries timer sync payloads over the HKWorkoutSession data channel (ADR-006 §3).
//  Shared by the iPhone and Watch targets.
//
//  While a workout is mirrored, HealthKit keeps its own connection between the
//  Watch's primary session and the iPhone's mirrored copy. `sendToRemoteWorkoutSession`
//  sends arbitrary data over it, and the other side receives it in
//  `workoutSession(_:didReceiveDataFromRemoteWorkoutSession:)`.
//
//  This transport doesn't own the session. On iPhone, `MirroredWorkoutObserver`
//  holds the mirrored session; on Watch, `WorkoutSessionManager` holds the primary.
//  The owner hands the current session in via `sessionProvider` and forwards
//  received data to `receive(_:)`.
//

import Foundation
import HealthKit
import os

@MainActor
final class HealthKitTimerSyncTransport: TimerSyncTransport {
    /// Returns the session to send over, or nil while there is none.
    private let sessionProvider: () -> HKWorkoutSession?

    var onPayload: ((TimerSyncPayload) -> Void)?
    var onReconnect: (() -> Void)?

    init(sessionProvider: @escaping () -> HKWorkoutSession?) {
        self.sessionProvider = sessionProvider
    }

    func publish(_ state: TimerState) {
        send(.state(state))
    }

    func send(_ intents: [TimerIntent]) {
        send(.intents(intents))
    }

    func requestStart(_ request: StartRequest) {
        // Before the Watch has started a session there is nothing to send over;
        // this only reaches the Watch if a session from an earlier workout is still up.
        send(.startRequest(request))
    }

    /// Delivers data received from the remote session. Called by the session's delegate owner.
    func receive(_ data: [Data]) {
        for item in data {
            do {
                onPayload?(try TimerSyncPayload(data: item))
            } catch {
                Logger.timerSync.error("Failed to decode HealthKit timer sync data: \(error.localizedDescription)")
            }
        }
    }

    /// Signals that a (new) session is connected. Called by the session's owner, e.g.
    /// when mirroring (re)starts, so the workout owner republishes its snapshot.
    func sessionDidConnect() {
        onReconnect?()
    }

    private func send(_ payload: TimerSyncPayload) {
        guard let session = sessionProvider() else { return }
        let data: Data
        do {
            data = try payload.encoded()
        } catch {
            Logger.timerSync.error("Failed to encode HealthKit timer sync data: \(error.localizedDescription)")
            return
        }
        // Fire-and-forget: this call is reported to occasionally never return, so it must
        // never block later sends. The WatchConnectivity transport covers any loss.
        Task {
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Logger.timerSync.warning("sendToRemoteWorkoutSession failed: \(error.localizedDescription)")
            }
        }
    }
}
