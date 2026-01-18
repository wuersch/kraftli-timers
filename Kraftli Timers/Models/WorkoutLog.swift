//
//  WorkoutLog.swift
//  Kraftli Timers
//
//  SwiftData model for completed workout history.
//

import Foundation
import SwiftData

/// A persistable record of a completed workout.
///
/// Stores a snapshot of workout parameters at completion time.
/// Exercise name is stored as a string (not a reference) to preserve
/// historical accuracy even if presets or exercises are later modified.
@Model
final class WorkoutLog {
    // MARK: - Persisted Properties
    // CloudKit requires default values for all non-optional attributes
    var id: UUID = UUID()
    var date: Date = Date()
    var exerciseName: String = ""
    var timerKindRawValue: String = TimerKind.emom.rawValue
    var durationSeconds: TimeInterval = 0
    var repsCompleted: Int?
    var roundsCompleted: Int?

    // MARK: - Computed Properties

    /// The timer kind parsed from the raw value.
    var timerKind: TimerKind {
        TimerKind(rawValue: timerKindRawValue) ?? .emom
    }

    /// Duration in whole minutes (rounded down).
    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }

    /// Formatted date for display (e.g., "Jan 10, 2026").
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Formatted time for display (e.g., "2:30 PM").
    var formattedTime: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Summary text for the workout (e.g., "20 min · 100 reps" or "20 min · 5 rounds").
    var summaryText: String {
        let duration = "\(durationMinutes) min"
        if let reps = repsCompleted {
            return "\(duration)\(UISeparator.dot)\(reps) reps"
        } else if let rounds = roundsCompleted {
            return "\(duration)\(UISeparator.dot)\(rounds) rounds"
        }
        return duration
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        exerciseName: String,
        timerKind: TimerKind,
        durationSeconds: TimeInterval,
        repsCompleted: Int? = nil,
        roundsCompleted: Int? = nil
    ) {
        precondition(durationSeconds > 0, "durationSeconds must be positive")
        precondition(
            timerKind != .emom || repsCompleted != nil,
            "EMOM workouts require repsCompleted"
        )
        precondition(
            timerKind != .amrap || roundsCompleted != nil,
            "AMRAP workouts require roundsCompleted"
        )

        self.id = id
        self.date = date
        self.exerciseName = exerciseName
        self.timerKindRawValue = timerKind.rawValue
        self.durationSeconds = durationSeconds
        self.repsCompleted = repsCompleted
        self.roundsCompleted = roundsCompleted
    }
}
