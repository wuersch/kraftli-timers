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
    var healthKitWorkoutUUID: UUID?
    /// True for a workout that was ended early (UC-0005 extension 1a). Its duration is
    /// then the active time up to the stop, and the count is what was done so far.
    var stoppedEarly: Bool = false
    /// The name of the session the workout was a step of, as it was then (UC-0015).
    /// Text, not a reference: renaming or deleting the session doesn't change the history.
    var sessionName: String?
    /// Identifies the run of the session, shared by all its steps' entries. Its one
    /// Health workout is linked to them through it.
    var sessionRunID: UUID?

    // MARK: - Computed Properties

    /// The timer kind parsed from the raw value.
    var timerKind: TimerKind {
        TimerKind(rawValue: timerKindRawValue) ?? .emom
    }

    /// Duration in whole minutes (rounded down).
    var durationMinutes: Int {
        durationSeconds.wholeMinutes
    }

    /// Formatted date for display (e.g., "Jan 10, 2026").
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// Formatted time for display (e.g., "2:30 PM").
    var formattedTime: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// The duration as shown in lists: "20 min", or to the second ("4:32") for For Time's
    /// finish time and for a workout stopped early, which rarely ends on a whole minute.
    var formattedDuration: String {
        if timerKind == .forTime || stoppedEarly {
            String(format: "%d:%02d", Int(durationSeconds) / 60, Int(durationSeconds) % 60)
        } else {
            "\(durationMinutes) min"
        }
    }

    /// Summary text for the workout (e.g., "20 min · 100 reps", "20 min · 5 rounds",
    /// or "4:32 · 100 reps" for For Time). A workout stopped early says so at the end:
    /// "2:43 · 5 rounds · stopped early".
    var summaryText: String {
        var parts = [formattedDuration]
        if let reps = repsCompleted {
            parts.append("\(reps) reps")
        } else if let rounds = roundsCompleted {
            parts.append("\(rounds) rounds")
        }
        if stoppedEarly {
            parts.append("stopped early")
        }
        return parts.joined(separator: UISeparator.dot)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        exerciseName: String,
        timerKind: TimerKind,
        durationSeconds: TimeInterval,
        repsCompleted: Int? = nil,
        roundsCompleted: Int? = nil,
        healthKitWorkoutUUID: UUID? = nil,
        stoppedEarly: Bool = false,
        sessionName: String? = nil,
        sessionRunID: UUID? = nil
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
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.stoppedEarly = stoppedEarly
        self.sessionName = sessionName
        self.sessionRunID = sessionRunID
    }
}
