//
//  WatchWorkoutCoordinator.swift
//  Kraftli Timers Watch App
//
//  Shared end-of-workout logic for the Watch timer views (EMOM, AMRAP, For Time):
//  ending the HealthKit session, then logging the workout (Watch-started) or
//  reporting it to the iPhone (iPhone-started).
//
//  Starting, pausing and stopping go through `TimerSessionController` (ADR-006);
//  this coordinator only handles what happens once a workout is over.
//

import SwiftUI
import SwiftData
import os

/// Configuration for a Watch workout, capturing the timer-specific details
/// that differ between the timer kinds.
struct WatchWorkoutConfig {
    let timerKind: TimerKind
    let exerciseName: String

    /// Identifies the workout on both devices; the iPhone's `WorkoutLog.id` for
    /// iPhone-started workouts.
    let workoutID: UUID

    /// True for workouts started on the iPhone: the iPhone writes the `WorkoutLog`,
    /// so the Watch reports its HealthKit data instead of logging.
    let startedOnPhone: Bool

    /// Creates a `WorkoutLog` from the completed workout data.
    /// AMRAP uses `roundsCompleted`; EMOM and For Time use `repsCompleted`.
    /// Called as soon as the workout completes, while the timer model still holds its result.
    let makeWorkoutLog: (_ healthKitUUID: UUID?) -> WorkoutLog
}

/// Ends a Watch workout's HealthKit session and records the result.
///
/// ## SwiftUI Integration
/// This is a plain struct with methods, not an `@Observable` class. The timer
/// views own the state (`timerModel`, `countdown`) and pass references to the
/// coordinator's methods. This avoids duplicating state ownership and keeps
/// SwiftUI's observation system working correctly.
struct WatchWorkoutCoordinator {
    let config: WatchWorkoutConfig
    let syncService: WatchTimerSyncService
    let sessionManager: WorkoutSessionManager

    /// Ends the timer and the HealthKit session (saving what was recorded), reports
    /// to the iPhone for iPhone-started workouts, and dismisses.
    func stopAndCleanup(
        timer: some WorkoutTimer,
        countdown: WatchCountdownCoordinator,
        dismiss: DismissAction
    ) {
        countdown.cancelCountdown()
        timer.reset()

        // A completed workout that is still saving (`handleWorkoutCompleted` is awaiting
        // HealthKit) finishes there: ending it again here would report it twice.
        if sessionManager.sessionState != .idle, !sessionManager.isEndingSession {
            // Capture metrics before ending session (they're cleared on end)
            let averageHeartRate = sessionManager.averageHeartRate
            let maxHeartRate = sessionManager.maxHeartRate
            let activeCalories = sessionManager.activeCalories

            Task {
                let uuid = await sessionManager.endSession()
                sessionManager.resetToIdle()

                if config.startedOnPhone {
                    sendWorkoutSessionEnded(
                        healthKitUUID: uuid,
                        averageHeartRate: averageHeartRate,
                        maxHeartRate: maxHeartRate,
                        activeCalories: activeCalories
                    )
                }
            }
        }

        dismiss()
    }

    /// Handles workout completion: ends the HealthKit session and either logs locally
    /// (Watch-started) or sends the HealthKit summary to the iPhone (iPhone-started).
    func handleWorkoutCompleted(modelContext: ModelContext) async {
        // Capture metrics before ending session (they're cleared on end)
        let averageHeartRate = sessionManager.averageHeartRate
        let maxHeartRate = sessionManager.maxHeartRate
        let activeCalories = sessionManager.activeCalories

        // Build the log before awaiting HealthKit: End pressed during the save resets the
        // timer model, which would record e.g. an AMRAP with 0 rounds.
        let log = config.startedOnPhone ? nil : config.makeWorkoutLog(nil)

        var healthKitUUID: UUID? = nil
        if sessionManager.sessionState == .running || sessionManager.sessionState == .paused {
            healthKitUUID = await sessionManager.endSession()
        }

        if let log {
            log.healthKitWorkoutUUID = healthKitUUID
            modelContext.insert(log)
            // Surface a save failure: this is the only SwiftData record of a
            // standalone workout, saved just as watchOS is most likely to suspend
            // the app. Swallowing the error lost the workout with no diagnostics.
            do {
                try modelContext.save()
            } catch {
                Logger.workoutLogging.error("Failed to save standalone Watch workout log: \(error.localizedDescription)")
            }
        } else {
            sendWorkoutSessionEnded(
                healthKitUUID: healthKitUUID,
                averageHeartRate: averageHeartRate,
                maxHeartRate: maxHeartRate,
                activeCalories: activeCalories
            )
        }

        Logger.healthKit.info("Watch \(config.timerKind.rawValue) workout completed, HealthKit UUID: \(healthKitUUID?.uuidString ?? "none"), startedOnPhone: \(config.startedOnPhone), avgHR: \(averageHeartRate.map { String(format: "%.0f", $0) } ?? "none")")

        // Reset to idle so the next timer run can start a fresh HK session.
        // Without this, sessionState stays .ended and startSession() bails out.
        sessionManager.resetToIdle()
    }

    // MARK: - Private

    private func sendWorkoutSessionEnded(
        healthKitUUID: UUID?,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        activeCalories: Double?
    ) {
        syncService.sendWorkoutSessionEnded(
            healthKitUUID: healthKitUUID,
            correlationID: config.workoutID,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            activeCalories: activeCalories,
            completion: nil
        )
    }
}
