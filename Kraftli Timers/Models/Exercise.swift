//
//  Exercise.swift
//  Kraftli Timers
//
//  SwiftData model for exercises.
//

import Foundation
import SwiftData

/// A persistable exercise model.
@Model
final class Exercise {
    // MARK: - Persisted Properties
    var id: UUID
    var name: String
    var exerciseDescription: String
    var formTips: [String]
    var muscleGroup: MuscleGroup
    var difficulty: Difficulty?

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        name: String,
        exerciseDescription: String,
        formTips: [String],
        muscleGroup: MuscleGroup,
        difficulty: Difficulty? = nil
    ) {
        self.id = id
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.formTips = formTips
        self.muscleGroup = muscleGroup
        self.difficulty = difficulty
    }

    #if !os(watchOS)
    /// Create Exercise from ExerciseData (JSON DTO)
    convenience init(from data: ExerciseData) {
        self.init(
            id: data.id,
            name: data.name,
            exerciseDescription: data.description,
            formTips: data.formTips,
            muscleGroup: data.muscleGroup,
            difficulty: data.difficulty
        )
    }
    #endif
}
