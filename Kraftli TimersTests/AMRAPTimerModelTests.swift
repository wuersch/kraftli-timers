//
//  AMRAPTimerModelTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

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
