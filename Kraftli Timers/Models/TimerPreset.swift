//
//  TimerPreset.swift
//  Kraftli Timers
//
//  SwiftData model for timer presets. Will be renamed to TimerPreset after migration.
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
        let minutes = Int(durationInterval) / 60
        return "\(kind.rawValue) ⸱ \(minutes) min"
    }

    var secondaryText: String {
        var parts: [String] = []
        if let exerciseName = exercise?.name {
            parts.append(exerciseName)
        }
        if let reps = targetReps {
            parts.append("\(reps) Reps")
        }
        return parts.joined(separator: " · ")
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
        self.id = id
        self.kindRawValue = kind.rawValue
        self.durationInterval = durationInterval
        self.targetReps = targetReps
        self.sortOrder = sortOrder
        self.exercise = exercise
    }
}
