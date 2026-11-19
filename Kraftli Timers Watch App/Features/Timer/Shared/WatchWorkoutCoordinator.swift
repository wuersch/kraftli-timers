//
//  WatchWorkoutCoordinator.swift
//  Kraftli Timers Watch App
//
//  Shared end-of-workout logic for the Watch timer screen: ending the HealthKit
//  session, then logging the workout (Watch-started) or reporting it to the
//  iPhone (iPhone-started).
//
//  Starting, pausing and stopping go through `TimerSessionController` (ADR-006);
//  this coordinator only handles what happens once a workout is over.
//

import SwiftUI
import SwiftData
import os

/// Ends a Watch workout's HealthKit session and records the result.
///
/// ## SwiftUI Integration
/// This is a plain struct with methods, not an `@Observable` class. The timer
/// screen owns the state (`model`, `countdown`) and passes references to the
/// coordinator's methods. This avoids duplicating state ownership and keeps
/// SwiftUI's observation system working correctly.
struct WatchWorkoutCoordinator {
    let timerKind: TimerKind

    /// Identifies the workout on both devices; the iPhone's `WorkoutLog.id` for
    /// iPhone-started workouts.
    let workoutID: UUID

    /// True for workouts started on the iPhone: the iPhone writes the `WorkoutLog`,
    /// so the Watch reports its HealthKit data instead of logging.
    let startedOnPhone: Bool

    let syncService: WatchTimerSyncService
    let sessionManager: WorkoutSessionManager

    /// Ends the timer and the HealthKit session (saving what was recorded), reports
    /// to the iPhone for iPhone-started workouts, and dismisses.
    ///
    /// - Parameter stoppedLog: The entry of a Watch-started workout that was stopped
    ///   early and ran long enough to be recorded (UC-0005 extension 1a). The iPhone
    ///   writes the entry of a workout it started.
    func stopAndCleanup(
        timer: some WorkoutTimer,
        countdown: CountdownCoordinator,
        stoppedLog: WorkoutLog? = nil,
        modelContext: ModelContext,
        dismiss: DismissAction
    ) {
        countdown.cancelCountdown()
        timer.reset()

        // A completed workout that is still saving (`handleWorkoutCompleted` is awaiting
        // HealthKit) finishes there: ending it again here would report it twice.
        if sessionManager.sessionState != .idle, !sessionManager.isEndingSession {
            Task {
                let summary = await sessionManager.endSession()
                sessionManager.resetToIdle()

                if startedOnPhone {
                    report(summary)
                } else if let stoppedLog {
                    save(stoppedLog, healthKitUUID: summary.healthKitUUID, in: modelContext)
                }
            }
        } else if let stoppedLog {
            // No Health workout to wait for (access denied, or tracking never began).
            save(stoppedLog, healthKitUUID: nil, in: modelContext)
        }

        dismiss()
    }

    /// Handles workout completion: ends the HealthKit session and either saves the log
    /// (Watch-started) or sends the HealthKit summary to the iPhone (iPhone-started).
    ///
    /// - Parameter log: The completed workout, for a Watch-started one. Built by the
    ///   caller the moment the workout completes, while the timer model still holds its
    ///   result: End pressed during the save below resets the model.
    func handleWorkoutCompleted(log: WorkoutLog?, modelContext: ModelContext) async {
        let summary: WorkoutSessionManager.Summary
        if sessionManager.sessionState == .running || sessionManager.sessionState == .paused {
            summary = await sessionManager.endSession()
        } else {
            summary = sessionManager.metricsSummary
        }

        if let log {
            save(log, healthKitUUID: summary.healthKitUUID, in: modelContext)
        } else {
            report(summary)
        }

        Logger.healthKit.info("Watch \(timerKind.rawValue) workout completed, HealthKit UUID: \(summary.healthKitUUID?.uuidString ?? "none"), startedOnPhone: \(startedOnPhone), avgHR: \(summary.averageHeartRate.map { String(format: "%.0f", $0) } ?? "none")")

        // Reset to idle so the next timer run can start a fresh HK session.
        // Without this, sessionState stays .ended and startSession() bails out.
        sessionManager.resetToIdle()
    }

    // MARK: - Private

    /// Writes the history entry of a Watch-started workout, linked to its Health workout.
    private func save(_ log: WorkoutLog, healthKitUUID: UUID?, in modelContext: ModelContext) {
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
    }

    /// Sends the session's HealthKit results to the iPhone, which wrote the workout log.
    private func report(_ summary: WorkoutSessionManager.Summary) {
        syncService.sendWorkoutSessionEnded(
            healthKitUUID: summary.healthKitUUID,
            correlationID: workoutID,
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            activeCalories: summary.activeCalories
        )
    }
}
