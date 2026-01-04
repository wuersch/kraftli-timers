//
//  TimerPreset.swift
//  Kraftli Timers
//
//  SwiftData model for timer presets.
//

import Foundation
import SwiftData

/// A persistable timer preset model.
@Model
final class TimerPreset {
    // MARK: - Persisted Properties
    var id: UUID
    var kindRawValue: String
    var durationInterval: TimeInterval
    var targetReps: Int?
    var sortOrder: Int

    // MARK: - Relationships
    var exercise: Exercise?

    // MARK: - Computed Properties
    var kind: TimerKind {
        TimerKind(rawValue: kindRawValue) ?? .emom
    }

    var duration: Duration {
        .seconds(durationInterval)
    }

    var primaryText: String {
        "\(kind.rawValue)\(UISeparator.dot)\(durationInterval.durationText)"
    }

    var secondaryText: String {
        var parts: [String] = []
        if let exerciseName = exercise?.name {
            parts.append(exerciseName)
        }
        if let reps = targetReps {
            parts.append("\(reps) Reps")
        }
        return parts.joined(separator: UISeparator.dot)
    }

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        kind: TimerKind,
        durationInterval: TimeInterval,
        targetReps: Int? = nil,
        sortOrder: Int = 0,
        exercise: Exercise? = nil
    ) {
        precondition(kind != .emom || targetReps != nil, "EMOM presets require targetReps")
        precondition(durationInterval > 0, "durationInterval must be positive")
        if let reps = targetReps {
            precondition(reps > 0, "targetReps must be positive")
        }

        self.id = id
        self.kindRawValue = kind.rawValue
        self.durationInterval = durationInterval
        self.targetReps = targetReps
        self.sortOrder = sortOrder
        self.exercise = exercise
    }
}

