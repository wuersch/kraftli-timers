//
//  ExerciseLoaderTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct ExerciseLoaderTests {

    @Test func loadBundled_returnsExercises() {
        let exercises = ExerciseLoader.loadBundled()

        #expect(!exercises.isEmpty)
    }

    @Test func loadBundled_exercisesHaveRequiredFields() {
        let exercises = ExerciseLoader.loadBundled()

        for exercise in exercises {
            #expect(!exercise.name.isEmpty)
            #expect(!exercise.description.isEmpty)
        }
    }

    @Test func loadBundled_exercisesHaveMuscleGroup() {
        let exercises = ExerciseLoader.loadBundled()

        for exercise in exercises {
            // MuscleGroup is required in our JSON schema
            #expect(MuscleGroup.allCases.contains(exercise.muscleGroup))
        }
    }

    @Test func load_async_returnsExercises() async {
        let exercises = await ExerciseLoader.load()

        #expect(!exercises.isEmpty)
    }
}
