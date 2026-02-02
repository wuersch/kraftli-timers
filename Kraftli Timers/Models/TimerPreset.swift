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
    // CloudKit requires default values for all non-optional attributes
    var id: UUID = UUID()
    var kindRawValue: String = TimerKind.emom.rawValue
    var durationInterval: TimeInterval = 20 * 60
    var targetReps: Int?
    var sortOrder: Int = 0

    /// Exercise ID for looking up exercise details from ExerciseRepository.
    /// This replaces the SwiftData relationship to avoid CloudKit sync issues.
    var exerciseId: UUID?

    // MARK: - Relationships (kept for migration)
    // TODO: Remove after migration has run on all devices
    var exercise: Exercise?

    // MARK: - Computed Properties
    var kind: TimerKind {
        TimerKind(rawValue: kindRawValue) ?? .emom
    }

    var duration: Duration {
        .seconds(durationInterval)
    }

    /// Look up exercise details from the in-memory repository.
    /// Returns nil if no exerciseId is set or exercise not found.
    var exerciseInfo: ExerciseInfo? {
        exerciseId.flatMap { ExerciseRepository.exercise(byId: $0) }
    }

    var primaryText: String {
        "\(kind.rawValue)\(UISeparator.dot)\(durationInterval.durationText)"
    }

    var secondaryText: String {
        var parts: [String] = []
        if let exerciseName = exerciseInfo?.name {
            parts.append(exerciseName)
        }
        if let reps = targetReps {
            parts.append("\(reps) Reps")
        }
        return parts.joined(separator: UISeparator.dot)
    }

    /// Duration of each interval for EMOM timers (total duration / reps).
    /// Returns 60 seconds as default if reps is not set.
    var intervalDuration: TimeInterval {
        guard let reps = targetReps, reps > 0 else {
            return 60
        }
        return durationInterval / Double(reps)
    }

    // MARK: - Constants

    /// Minimum allowed interval duration in seconds.
    static let minimumIntervalDuration: TimeInterval = 3

    /// Calculates maximum reps for a given duration based on minimum interval.
    static func maximumReps(forDuration duration: TimeInterval) -> Int {
        max(1, Int(duration / minimumIntervalDuration))
    }

    // MARK: - Initialization

    /// Creates a new preset with an exercise ID (preferred for new code).
    init(
        id: UUID = UUID(),
        kind: TimerKind,
        durationInterval: TimeInterval,
        targetReps: Int? = nil,
        sortOrder: Int = 0,
        exerciseId: UUID? = nil
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
        self.exerciseId = exerciseId
    }
}

