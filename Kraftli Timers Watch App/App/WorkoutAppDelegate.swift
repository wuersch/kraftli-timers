//
//  WorkoutAppDelegate.swift
//  Kraftli Timers Watch App
//
//  Receives HKWorkoutConfiguration from iPhone via startWatchApp(toHandle:).
//  This is the entry point for Scenario C (iPhone-initiated workouts).
//
//  ## How It Works
//  1. iPhone calls `healthStore.startWatchApp(toHandle: configuration)`
//  2. watchOS launches our Watch app (if not already running)
//  3. watchOS delivers the configuration to `handle(_ workoutConfiguration:)`
//  4. We start an HKWorkoutSession and begin mirroring to iPhone
//

import WatchKit
import HealthKit
import os

final class WorkoutAppDelegate: NSObject, WKApplicationDelegate {
    /// Shared workout session manager, injected into views via @Environment.
    let workoutSessionManager = WorkoutSessionManager()

    /// Called by watchOS when iPhone sends a workout configuration via startWatchApp(toHandle:).
    ///
    /// This is the system-level entry point for iPhone-initiated workouts (Scenario C).
    /// The configuration arrives via HealthKit, not WatchConnectivity.
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Logger.workoutSession.info("Received workout configuration from iPhone: \(String(describing: workoutConfiguration.activityType))")

        Task {
            do {
                try await workoutSessionManager.startSession(configuration: workoutConfiguration)
                try await workoutSessionManager.startMirroring()
                Logger.workoutSession.info("Workout session started from iPhone configuration")
            } catch {
                Logger.workoutSession.error("Failed to start workout session from iPhone: \(error.localizedDescription)")
            }
        }
    }

    /// Called when the app needs to recover from a crash during an active workout.
    ///
    /// watchOS preserves active HKWorkoutSession across app launches.
    /// If the app was terminated during a workout, this method recovers the session.
    func handleActiveWorkoutRecovery() {
        Logger.workoutSession.info("Active workout recovery requested")

        Task {
            do {
                try await workoutSessionManager.recoverActiveSession()
            } catch {
                Logger.workoutSession.error("Failed to recover workout session: \(error.localizedDescription)")
            }
        }
    }
}
