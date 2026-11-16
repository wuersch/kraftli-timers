//
//  ExerciseTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

// MARK: - ExerciseInfo Struct Tests

struct ExerciseInfoTests {

    @Test func decode_mapsAllFields() throws {
        let json = Data("""
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Test Exercise",
            "description": "A test exercise for unit testing",
            "formTips": ["Keep back straight", "Breathe steadily"],
            "muscleGroup": "\(MuscleGroup.fullBody.rawValue)",
            "difficulty": "\(Difficulty.intermediate.rawValue)"
        }
        """.utf8)

        let exerciseInfo = try JSONDecoder().decode(ExerciseInfo.self, from: json)

        #expect(exerciseInfo.id == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        #expect(exerciseInfo.name == "Test Exercise")
        #expect(exerciseInfo.description == "A test exercise for unit testing")
        #expect(exerciseInfo.formTips == ["Keep back straight", "Breathe steadily"])
        #expect(exerciseInfo.muscleGroup == .fullBody)
        #expect(exerciseInfo.difficulty == .intermediate)
    }

    @Test func decode_handlesMissingDifficulty() throws {
        let json = Data("""
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Easy Exercise",
            "description": "No difficulty specified",
            "formTips": [],
            "muscleGroup": "\(MuscleGroup.core.rawValue)"
        }
        """.utf8)

        let exerciseInfo = try JSONDecoder().decode(ExerciseInfo.self, from: json)

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
