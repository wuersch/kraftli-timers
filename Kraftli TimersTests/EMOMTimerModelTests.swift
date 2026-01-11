//
//  EMOMTimerModelTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

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
