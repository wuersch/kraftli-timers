//
//  ExerciseTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct ExerciseTests {

    @Test func init_fromExerciseData_mapsAllFields() {
        let data = ExerciseData(
            id: UUID(),
            name: "Test Exercise",
            description: "A test exercise for unit testing",
            formTips: ["Keep back straight", "Breathe steadily"],
            muscleGroup: .fullBody,
            difficulty: .intermediate
        )

        let exercise = Exercise(from: data)

        #expect(exercise.id == data.id)
        #expect(exercise.name == data.name)
        #expect(exercise.exerciseDescription == data.description)
        #expect(exercise.formTips == data.formTips)
        #expect(exercise.muscleGroup == data.muscleGroup)
        #expect(exercise.difficulty == data.difficulty)
    }

    @Test func init_fromExerciseData_handlesNilDifficulty() {
        let data = ExerciseData(
            id: UUID(),
            name: "Easy Exercise",
            description: "No difficulty specified",
            formTips: [],
            muscleGroup: .core,
            difficulty: nil
        )

        let exercise = Exercise(from: data)

        #expect(exercise.difficulty == nil)
        #expect(exercise.muscleGroup == .core)
    }

    @Test func init_fromExerciseData_preservesFormTips() {
        let tips = ["Tip 1", "Tip 2", "Tip 3"]
        let data = ExerciseData(
            id: UUID(),
            name: "Exercise with Tips",
            description: "Has multiple form tips",
            formTips: tips,
            muscleGroup: .upperBody,
            difficulty: .beginner
        )

        let exercise = Exercise(from: data)

        #expect(exercise.formTips?.count == 3)
        #expect(exercise.formTips == tips)
    }
}
