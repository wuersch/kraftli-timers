//
//  WorkoutLoggingService.swift
//  Kraftli Timers
//
//  Service for logging completed workouts to persistent storage.
//

import Foundation
import SwiftData

/// Protocol for logging completed workouts.
///
/// Abstracted as a protocol to enable:
/// - Testing with mock implementations
/// - Future HealthKit integration alongside SwiftData logging
protocol WorkoutLoggingService {
    /// Logs a completed workout to persistent storage.
    ///
    /// - Parameters:
    ///   - exerciseName: The name of the exercise performed.
    ///   - timerKind: The type of timer (EMOM or AMRAP).
    ///   - durationSeconds: Total workout duration in seconds.
    ///   - repsCompleted: Number of reps completed (EMOM only).
    ///   - roundsCompleted: Number of rounds completed (AMRAP only).
    func logWorkout(
        exerciseName: String,
        timerKind: TimerKind,
        durationSeconds: TimeInterval,
        repsCompleted: Int?,
        roundsCompleted: Int?
    )
}

/// Default implementation that persists workouts to SwiftData.
final class DefaultWorkoutLoggingService: WorkoutLoggingService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func logWorkout(
        exerciseName: String,
        timerKind: TimerKind,
        durationSeconds: TimeInterval,
        repsCompleted: Int?,
        roundsCompleted: Int?
    ) {
        let workoutLog = WorkoutLog(
            exerciseName: exerciseName,
            timerKind: timerKind,
            durationSeconds: durationSeconds,
            repsCompleted: repsCompleted,
            roundsCompleted: roundsCompleted
        )

        modelContext.insert(workoutLog)

        // Explicit save to ensure data persists before app backgrounds
        do {
            try modelContext.save()
        } catch {
            // Log error in production; for now just print
            print("Failed to save workout log: \(error)")
        }
    }
}

/// Silent implementation for testing or when logging should be disabled.
final class SilentWorkoutLoggingService: WorkoutLoggingService {
    func logWorkout(
        exerciseName: String,
        timerKind: TimerKind,
        durationSeconds: TimeInterval,
        repsCompleted: Int?,
        roundsCompleted: Int?
    ) {
        // No-op: intentionally does nothing
    }
}
