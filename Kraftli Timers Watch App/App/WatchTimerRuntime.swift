//
//  WatchTimerRuntime.swift
//  Kraftli Timers Watch App
//
//  Owns the Watch's workout objects for the whole app lifetime (ADR-006): the
//  HealthKit session manager, the timer session controller and the start handshake.
//
//  ## Why a shared instance
//  Two system entry points need these objects, and their order isn't guaranteed:
//  `App.init` (which activates WatchConnectivity and may immediately receive a
//  persisted start request) and `WorkoutAppDelegate.handle(_ workoutConfiguration:)`.
//  A lazily created shared instance exists before whichever comes first, so no
//  start request or session hand-off is dropped on a cold launch.
//

import HealthKit
import WatchKit
import os

@MainActor
final class WatchTimerRuntime {
    static let shared = WatchTimerRuntime()

    let sessionManager = WorkoutSessionManager()
    let timerSession: TimerSessionController
    let starter: WatchWorkoutStarter
    /// Holds the Health session of a training session's run across its steps (ADR-0012).
    let sessionFollower: WatchSessionFollower

    /// Keeps the app on screen while following an iPhone-owned workout without a
    /// HealthKit session (after yielding).
    private var keepAlive: WKExtendedRuntimeSession?

    private init() {
        let sessionManager = self.sessionManager
        let healthKitTransport = HealthKitTimerSyncTransport { sessionManager.currentSession }
        sessionManager.onRemoteData = { healthKitTransport.receive($0) }
        sessionManager.onSessionConnected = { healthKitTransport.sessionDidConnect() }

        let transport = CompositeTimerSyncTransport(transports: [
            WatchConnectivityTimerSyncTransport(connectivity: .shared),
            healthKitTransport
        ])
        let timerSession = TimerSessionController(transport: transport)
        self.timerSession = timerSession

        let sessionFollower = WatchSessionFollower(
            pauseHealthSession: { sessionManager.pause() },
            resumeHealthSession: { sessionManager.resume() },
            saveHealthSession: { context in
                Task {
                    let summary = await sessionManager.endSession()
                    sessionManager.resetToIdle()
                    // The run's ID stands where a single workout's ID would: the iPhone
                    // links the Health workout to every step's entry through it.
                    DefaultWatchTimerSyncService(connectivity: .shared).sendWorkoutSessionEnded(
                        healthKitUUID: summary.healthKitUUID,
                        correlationID: context.runID,
                        averageHeartRate: summary.averageHeartRate,
                        maxHeartRate: summary.maxHeartRate,
                        activeCalories: summary.activeCalories
                    )
                }
            },
            discardHealthSession: { sessionManager.discardSession() }
        )
        self.sessionFollower = sessionFollower

        // Filled in below, once `self` is fully initialized.
        var startKeepAlive: () -> Void = {}
        var endKeepAlive: () -> Void = {}
        starter = WatchWorkoutStarter(
            controller: timerSession,
            transport: transport,
            sessionFollower: sessionFollower,
            startHealthSession: { kind in
                try await Self.startSession(on: sessionManager, configuration: Self.configuration(for: kind))
            },
            discardHealthSession: { sessionManager.discardSession() },
            isHealthAccessUndecided: { sessionManager.isAuthorizationUndecided },
            requestHealthAccess: {
                do {
                    try await sessionManager.requestAuthorization()
                } catch {
                    // HealthKit couldn't ask. The workout runs without Health (UC-0004 2a).
                    Logger.healthKit.error("Health access request failed: \(error.localizedDescription)")
                }
            },
            startKeepAlive: { startKeepAlive() },
            endKeepAlive: { endKeepAlive() }
        )
        startKeepAlive = { [weak self] in self?.startKeepAlive() }
        endKeepAlive = { [weak self] in self?.endKeepAlive() }
    }

    /// Starts a HealthKit session for a workout the iPhone launched the app for.
    func handle(_ configuration: HKWorkoutConfiguration) {
        let sessionManager = sessionManager
        starter.watchAppLaunched {
            try await Self.startSession(on: sessionManager, configuration: configuration)
        }
    }

    // MARK: - Private

    /// Starts the session and, without waiting, its mirroring to the iPhone. Until
    /// mirroring is up, snapshots travel over WatchConnectivity only.
    private static func startSession(
        on sessionManager: WorkoutSessionManager,
        configuration: HKWorkoutConfiguration
    ) async throws {
        try await sessionManager.startSession(configuration: configuration)
        Task {
            do {
                try await sessionManager.startMirroring()
            } catch {
                Logger.workoutSession.error("Failed to start mirroring: \(error.localizedDescription)")
            }
        }
    }

    private static func configuration(for kind: TimerKind) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = kind.healthKitActivityType
        configuration.locationType = .indoor
        return configuration
    }

    private func startKeepAlive() {
        guard keepAlive == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.start()
        keepAlive = session
    }

    private func endKeepAlive() {
        keepAlive?.invalidate()
        keepAlive = nil
    }
}
