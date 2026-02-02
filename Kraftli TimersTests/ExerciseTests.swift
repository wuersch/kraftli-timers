//
//  ExerciseTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

// MARK: - Exercise @Model Tests (legacy, for migration)

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

        #expect(exercise.formTips.count == 3)
        #expect(exercise.formTips == tips)
    }
}

// MARK: - ExerciseInfo Struct Tests

struct ExerciseInfoTests {

    @Test func init_fromExerciseData_mapsAllFields() {
        let data = ExerciseData(
            id: UUID(),
            name: "Test Exercise",
            description: "A test exercise for unit testing",
            formTips: ["Keep back straight", "Breathe steadily"],
            muscleGroup: .fullBody,
            difficulty: .intermediate
        )

        let exerciseInfo = ExerciseInfo(from: data)

        #expect(exerciseInfo.id == data.id)
        #expect(exerciseInfo.name == data.name)
        #expect(exerciseInfo.description == data.description)
        #expect(exerciseInfo.formTips == data.formTips)
        #expect(exerciseInfo.muscleGroup == data.muscleGroup)
        #expect(exerciseInfo.difficulty == data.difficulty)
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

        let exerciseInfo = ExerciseInfo(from: data)

        #expect(exerciseInfo.difficulty == nil)
        #expect(exerciseInfo.muscleGroup == .core)
    }

    @Test func directInit_createsExerciseInfo() {
        let id = UUID()
        let exerciseInfo = ExerciseInfo(
            id: id,
            name: "Direct Init Exercise",
            description: "Created directly",
            formTips: ["Tip 1"],
            muscleGroup: .lowerBody,
            difficulty: .advanced
        )

        #expect(exerciseInfo.id == id)
        #expect(exerciseInfo.name == "Direct Init Exercise")
        #expect(exerciseInfo.description == "Created directly")
        #expect(exerciseInfo.formTips == ["Tip 1"])
        #expect(exerciseInfo.muscleGroup == .lowerBody)
        #expect(exerciseInfo.difficulty == .advanced)
    }

    @Test func exerciseInfo_isHashable() {
        let id = UUID()
        let exercise1 = ExerciseInfo(id: id, name: "Test", description: "", formTips: [], muscleGroup: .fullBody)
        let exercise2 = ExerciseInfo(id: id, name: "Test", description: "", formTips: [], muscleGroup: .fullBody)

        #expect(exercise1 == exercise2)
        #expect(exercise1.hashValue == exercise2.hashValue)
    }
}

// MARK: - ExerciseRepository Tests

struct ExerciseRepositoryTests {

    @Test func load_populatesExercises() {
        ExerciseRepository.load()

        #expect(ExerciseRepository.all.count > 0)
    }

    @Test func exerciseById_findsExercise() {
        ExerciseRepository.load()

        guard let firstExercise = ExerciseRepository.all.first else {
            Issue.record("No exercises loaded")
            return
        }

        let found = ExerciseRepository.exercise(byId: firstExercise.id)

        #expect(found?.id == firstExercise.id)
        #expect(found?.name == firstExercise.name)
    }

    @Test func exerciseById_returnsNilForUnknownId() {
        ExerciseRepository.load()

        let unknownId = UUID()
        let result = ExerciseRepository.exercise(byId: unknownId)

        #expect(result == nil)
    }

    @Test func exerciseByName_findsExercise() {
        ExerciseRepository.load()

        // This assumes 6-Count Burpees exists in the JSON
        let found = ExerciseRepository.exercise(byName: "6-Count Burpees")

        #expect(found != nil)
        #expect(found?.name == "6-Count Burpees")
    }

    @Test func exerciseByName_returnsNilForUnknownName() {
        ExerciseRepository.load()

        let result = ExerciseRepository.exercise(byName: "NonExistent Exercise")

        #expect(result == nil)
    }

    @Test func all_isSortedAlphabetically() {
        ExerciseRepository.load()

        let names = ExerciseRepository.all.map(\.name)
        let sortedNames = names.sorted()

        #expect(names == sortedNames)
    }
}
