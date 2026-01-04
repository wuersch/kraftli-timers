//
//  Kraftli_TimersTests.swift
//  Kraftli TimersTests
//
//  Created by Michael Würsch on 17.12.2025.
//

import Foundation
import Testing
@testable import Kraftli_Timers

// MARK: - Mock Timer Provider

/// A mock timer provider for unit tests that doesn't create real timers.
/// This eliminates MainActor contention and avoids resource accumulation.
final class MockTimerProvider: TimerProvider {
    var scheduleTimerCalled = false
    var invalidateTimerCalled = false
    private var tickHandler: ((Any) -> Void)?

    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping (Any) -> Void) -> Any {
        scheduleTimerCalled = true
        tickHandler = block
        // Return a dummy timer token
        return "MockTimer"
    }

    func invalidateTimer(_ timer: Any) {
        invalidateTimerCalled = true
        tickHandler = nil
    }

    /// Manually trigger a tick for testing timer logic
    func simulateTick() {
        tickHandler?("MockTimer")
    }
}

// MARK: - TimerPreset Tests

struct TimerPresetTests {

    @Test func durationInterval_storesSeconds() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 1200, // 20 minutes
            targetReps: 100
        )

        #expect(preset.durationInterval == 1200)
    }

    @Test func duration_convertsToSwiftDuration() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 1200,
            targetReps: 100
        )

        #expect(preset.duration == .seconds(1200))
    }

    @Test func primaryText_formatsEMOMCorrectly() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100
        )

        #expect(preset.primaryText == "EMOM\(UISeparator.dot)20 min")
    }

    @Test func primaryText_formatsAMRAPCorrectly() {
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 15 * 60,
            targetReps: nil
        )

        #expect(preset.primaryText == "AMRAP\(UISeparator.dot)15 min")
    }

    @Test func secondaryText_includesExerciseAndRepsForEMOM() {
        let exercise = Exercise(name: "6-Count Burpees")
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100,
            exercise: exercise
        )

        #expect(preset.secondaryText == "6-Count Burpees · 100 Reps")
    }

    @Test func secondaryText_includesOnlyExerciseForAMRAP() {
        let exercise = Exercise(name: "Pull-ups")
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil,
            exercise: exercise
        )

        #expect(preset.secondaryText == "Pull-ups")
    }

    @Test func secondaryText_handlesNoExercise() {
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil,
            exercise: nil
        )

        #expect(preset.secondaryText == "")
    }

    @Test func kind_parsesFromRawValue() {
        let emomPreset = TimerPreset(kind: .emom, durationInterval: 60, targetReps: 10)
        let amrapPreset = TimerPreset(kind: .amrap, durationInterval: 60)

        #expect(emomPreset.kind == .emom)
        #expect(amrapPreset.kind == .amrap)
    }
}

// MARK: - EMOMTimerModel Tests

struct EMOMTimerModelTests {

    @Test @MainActor func initialState_isNotRunning() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 60)
        #expect(model.intervalTimeRemaining == 10)
    }

    @Test @MainActor func start_setsIsRunningTrue() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()

        #expect(model.isRunning == true)
        model.reset()
    }

    @Test @MainActor func pause_setsIsRunningFalse() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()
        model.pause()

        #expect(model.isRunning == false)
        model.reset()
    }

    @Test @MainActor func reset_restoresInitialState() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()
        model.pause()
        model.reset()

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 60)
        #expect(model.intervalTimeRemaining == 10)
    }

    @Test @MainActor func totalIntervals_calculatedCorrectly() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.totalIntervals == 6)
    }

    @Test @MainActor func completedIntervals_startsAtZero() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.completedIntervals == 0)
    }

    @Test @MainActor func overallProgress_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.overallProgress == 1.0)
    }

    @Test @MainActor func intervalProgress_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.intervalProgress == 1.0)
    }

    @Test @MainActor func convenienceInit_calculatesIntervalFromReps() {
        let model = EMOMTimerModel(
            totalReps: 10,
            totalMinutes: 1,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        // 60 seconds / 10 reps = 6 seconds per interval
        #expect(model.intervalTimeRemaining == 6)
        #expect(model.totalIntervals == 10)
    }
}

// MARK: - AMRAPTimerModel Tests

struct AMRAPTimerModelTests {

    @Test @MainActor func initialState_isNotRunning() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 300)
        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func start_setsIsRunningTrue() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        model.start()

        #expect(model.isRunning == true)
        model.reset()
    }

    @Test @MainActor func pause_setsIsRunningFalse() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        model.start()
        model.pause()

        #expect(model.isRunning == false)
        model.reset()
    }

    @Test @MainActor func reset_restoresInitialState() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        model.start()
        model.incrementRoundsCompleted()
        model.incrementRoundsCompleted()
        model.pause()
        model.reset()

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 300)
        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func incrementRoundsCompleted_incrementsCount() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        model.incrementRoundsCompleted()
        #expect(model.roundsCompleted == 1)

        model.incrementRoundsCompleted()
        #expect(model.roundsCompleted == 2)
    }

    @Test @MainActor func decrementRoundsCompleted_decrementsCount() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        model.incrementRoundsCompleted()
        model.incrementRoundsCompleted()
        model.decrementRoundsCompleted()

        #expect(model.roundsCompleted == 1)
    }

    @Test @MainActor func decrementRoundsCompleted_doesNotGoBelowZero() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        model.decrementRoundsCompleted()

        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func progress_startsAtOne() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        #expect(model.progress == 1.0)
    }

    @Test @MainActor func elapsedTime_startsAtZero() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider()
        )

        #expect(model.elapsedTime == 0)
    }
}

// MARK: - ExerciseLoader Tests

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

// MARK: - Exercise Model Tests

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
