//
//  PhoneTimerRuntime.swift
//  Kraftli Timers
//
//  Owns the iPhone's workout objects for the whole app lifetime (ADR-006): the timer
//  session controller, the start handshake, the Watch message coordinator and the
//  workout recorder. The counterpart of the Watch's `WatchTimerRuntime`.
//

import SwiftData
import os

/// Builds and holds the objects that connect the iPhone to a workout and to the Watch.
///
/// Created once in `App.init`, so everything is wired before any message arrives —
/// including a background WCSession launch with no scene, where no view's `onAppear`
/// ever runs.
@MainActor
final class PhoneTimerRuntime {
    /// The app's one timer session (ADR-006). One instance for the app's lifetime, because
    /// its WatchConnectivity transport is the only receiver of timer sync payloads.
    let timerSession: TimerSessionController

    /// Starts iPhone-initiated workouts through the Watch handshake (ADR-006 §4).
    let workoutStarter: PhoneWorkoutStarter

    /// Routes Watch messages for the whole app lifetime.
    let messageCoordinator: PhoneMessageCoordinator

    /// Writes completed workouts to the log and to Health.
    let workoutRecorder: any WorkoutRecorder

    /// Holds the Watch's mirrored workout session for the HealthKit sync channel.
    private let mirroredWorkoutObserver = MirroredWorkoutObserver()

    init(modelContext: ModelContext) {
        // The message coordinator gets the model context right away, so a Watch
        // WorkoutSessionEndedMessage can link its HealthKit UUID to the WorkoutLog even on
        // a background launch.
        messageCoordinator = PhoneMessageCoordinator(modelContext: modelContext)

        let healthKitService = DefaultHealthKitService()
        workoutRecorder = DefaultWorkoutRecorder(modelContext: modelContext, healthKit: healthKitService)

        // Timer sync (ADR-006): publish on WatchConnectivity and, while the Watch mirrors a
        // workout, on the HealthKit session's data channel.
        let mirroredWorkoutObserver = mirroredWorkoutObserver
        let healthKitTransport = HealthKitTimerSyncTransport { mirroredWorkoutObserver.currentSession }
        mirroredWorkoutObserver.onRemoteData = { healthKitTransport.receive($0) }
        mirroredWorkoutObserver.onSessionConnected = { healthKitTransport.sessionDidConnect() }
        let timerSession = TimerSessionController(
            transport: CompositeTimerSyncTransport(transports: [
                WatchConnectivityTimerSyncTransport(connectivity: .shared),
                healthKitTransport
            ])
        )
        self.timerSession = timerSession
        workoutStarter = PhoneWorkoutStarter(
            controller: timerSession,
            isWatchAppAvailable: { WatchConnectivityService.shared.isWatchAppAvailable },
            launchWatchApp: { config in
                try await healthKitService.startWorkoutOnWatch(activityType: config.kind.healthKitActivityType)
            }
        )

        // Receive the Watch's mirrored workout session. Set here rather than in a view's
        // onAppear, so a session mirrored during a background launch isn't missed.
        healthKitService.setupMirroringHandler { session in
            Logger.healthKit.info("Received mirrored workout session from Watch")
            mirroredWorkoutObserver.setSession(session)
        }

        // Activate WatchConnectivity *after* the coordinator's message handler is registered.
        WatchConnectivityService.shared.activate()
    }
}
