//
//  Exercise.swift
//  Kraftli Timers
//
//  SwiftData model for exercises. Will be renamed to Exercise after migration.
//

import Foundation
import SwiftData

/// A persistable exercise model.
/// Designed for v2+ expansion with description, muscle groups, calories, and difficulty.
@Model
final class Exercise {
    // MARK: - Persisted Properties
    var id: UUID
    var name: String

    // MARK: - v2+ Ready (optional for now)
    var exerciseDescription: String?
    // Note: muscleGroups, calories, difficulty will be added in v2

    // MARK: - Initialization
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    // MARK: - Default Exercises
    static let defaultExercises: [String] = [
        "Pull-ups",
        "6-Count Burpees",
        "Navy Seal Burpees",
        "Push-ups"
    ]
}
