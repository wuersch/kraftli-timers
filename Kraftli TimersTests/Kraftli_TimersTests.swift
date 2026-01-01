//
//  Kraftli_TimersTests.swift
//  Kraftli TimersTests
//
//  Created by Michael Würsch on 17.12.2025.
//

import Foundation
import Testing
@testable import Kraftli_Timers

// MARK: - TimerPreset Tests

struct TimerPresetTests {

    @Test func durationInterval_convertsToSeconds() {
        let preset = TimerPreset(
            id: UUID(),
            kind: .emom,
            duration: .seconds(20 * 60),
            targetReps: 100,
            exercise: Exercise(name: "Burpees")
        )

        #expect(preset.durationInterval == 1200) // 20 minutes = 1200 seconds
    }

    @Test func primaryText_formatsEMOMCorrectly() {
        let preset = TimerPreset(
            id: UUID(),
            kind: .emom,
            duration: .seconds(20 * 60),
            targetReps: 100,
            exercise: Exercise(name: "Burpees")
        )

        #expect(preset.primaryText == "EMOM ⸱ 20 min")
    }

    @Test func primaryText_formatsAMRAPCorrectly() {
        let preset = TimerPreset(
            id: UUID(),
            kind: .amrap,
            duration: .seconds(15 * 60),
            targetReps: nil,
            exercise: Exercise(name: "Pull-ups")
        )

        #expect(preset.primaryText == "AMRAP ⸱ 15 min")
    }

    @Test func secondaryText_includesExerciseAndRepsForEMOM() {
        let preset = TimerPreset(
            id: UUID(),
            kind: .emom,
            duration: .seconds(20 * 60),
            targetReps: 100,
            exercise: Exercise(name: "6-Count Burpees")
        )

        #expect(preset.secondaryText == "6-Count Burpees · 100 Reps")
    }

    @Test func secondaryText_includesOnlyExerciseForAMRAP() {
        let preset = TimerPreset(
            id: UUID(),
            kind: .amrap,
            duration: .seconds(20 * 60),
            targetReps: nil,
            exercise: Exercise(name: "Pull-ups")
        )

        #expect(preset.secondaryText == "Pull-ups")
    }

    @Test func exercise_equalityByName() {
        let exercise1 = Exercise(name: "Burpees")
        let exercise2 = Exercise(name: "Burpees")
        let exercise3 = Exercise(name: "Push-ups")

        #expect(exercise1 == exercise2)
        #expect(exercise1 != exercise3)
    }

    @Test func defaults_containsFourPresets() {
        #expect(TimerPreset.defaults.count == 4)
    }
}

// MARK: - EMOMTimerModel Tests

struct EMOMTimerModelTests {

    @Test @MainActor func initialState_isNotRunning() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: FoundationTimerProvider(),
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
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()

        #expect(model.isRunning == true)
    }

    @Test @MainActor func pause_setsIsRunningFalse() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()
        model.pause()

        #expect(model.isRunning == false)
    }

    @Test @MainActor func reset_restoresInitialState() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: FoundationTimerProvider(),
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
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.totalIntervals == 6)
    }

    @Test @MainActor func completedIntervals_startsAtZero() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.completedIntervals == 0)
    }

    @Test @MainActor func overallProgress_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.overallProgress == 1.0)
    }

    @Test @MainActor func intervalProgress_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalDuration: 10,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.intervalProgress == 1.0)
    }

    @Test @MainActor func convenienceInit_calculatesIntervalFromReps() {
        let model = EMOMTimerModel(
            totalReps: 10,
            totalMinutes: 1,
            timerProvider: FoundationTimerProvider(),
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
            timerProvider: FoundationTimerProvider()
        )

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 300)
        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func start_setsIsRunningTrue() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
        )

        model.start()

        #expect(model.isRunning == true)
    }

    @Test @MainActor func pause_setsIsRunningFalse() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
        )

        model.start()
        model.pause()

        #expect(model.isRunning == false)
    }

    @Test @MainActor func reset_restoresInitialState() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
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
            timerProvider: FoundationTimerProvider()
        )

        model.incrementRoundsCompleted()
        #expect(model.roundsCompleted == 1)

        model.incrementRoundsCompleted()
        #expect(model.roundsCompleted == 2)
    }

    @Test @MainActor func decrementRoundsCompleted_decrementsCount() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
        )

        model.incrementRoundsCompleted()
        model.incrementRoundsCompleted()
        model.decrementRoundsCompleted()

        #expect(model.roundsCompleted == 1)
    }

    @Test @MainActor func decrementRoundsCompleted_doesNotGoBelowZero() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
        )

        model.decrementRoundsCompleted()

        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func progress_startsAtOne() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
        )

        #expect(model.progress == 1.0)
    }

    @Test @MainActor func elapsedTime_startsAtZero() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: FoundationTimerProvider()
        )

        #expect(model.elapsedTime == 0)
    }
}
