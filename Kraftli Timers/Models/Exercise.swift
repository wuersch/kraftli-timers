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
    // CloudKit requires default values or optionals for all attributes
    var id: UUID = UUID()
    var name: String = ""
    var exerciseDescription: String = ""
    var formTips: [String] = []
    var muscleGroupRawValue: String = MuscleGroup.fullBody.rawValue
    var difficultyRawValue: String?

    // MARK: - Computed Properties
    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRawValue) ?? .fullBody }
        set { muscleGroupRawValue = newValue.rawValue }
    }

    var difficulty: Difficulty? {
        get { difficultyRawValue.flatMap { Difficulty(rawValue: $0) } }
        set { difficultyRawValue = newValue?.rawValue }
    }

    // MARK: - Relationships
    // CloudKit requires inverse relationships
    @Relationship(inverse: \TimerPreset.exercise)
    var presets: [TimerPreset]?

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
}
