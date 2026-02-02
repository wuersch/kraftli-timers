//
//  ExerciseInfo.swift
//  Kraftli Timers
//
//  Lightweight exercise data for in-memory use.
//  Loaded from bundled JSON, not persisted to SwiftData.
//

import Foundation

/// Lightweight exercise data for in-memory use.
///
/// This struct replaces the @Model Exercise class for runtime use.
/// Exercises are static reference data loaded from bundled JSON at app startup.
/// Only the exercise ID is persisted in TimerPreset; exercise details are
/// looked up from ExerciseRepository when needed.
struct ExerciseInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let formTips: [String]
    let muscleGroup: MuscleGroup
    let difficulty: Difficulty?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        formTips: [String],
        muscleGroup: MuscleGroup,
        difficulty: Difficulty? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.formTips = formTips
        self.muscleGroup = muscleGroup
        self.difficulty = difficulty
    }

    /// Create ExerciseInfo from ExerciseData (JSON DTO).
    init(from data: ExerciseData) {
        self.id = data.id
        self.name = data.name
        self.description = data.description
        self.formTips = data.formTips
        self.muscleGroup = data.muscleGroup
        self.difficulty = data.difficulty
    }
}
