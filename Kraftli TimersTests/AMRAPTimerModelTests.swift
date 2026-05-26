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
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 300)
        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func start_setsIsRunningTrue() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()

        #expect(model.isRunning == true)
        model.reset()
    }

    @Test @MainActor func pause_setsIsRunningFalse() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.start()
        model.pause()

        #expect(model.isRunning == false)
        model.reset()
    }

    @Test @MainActor func reset_restoresInitialState() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
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
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.incrementRoundsCompleted()
        #expect(model.roundsCompleted == 1)

        model.incrementRoundsCompleted()
        #expect(model.roundsCompleted == 2)
    }

    @Test @MainActor func decrementRoundsCompleted_decrementsCount() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.incrementRoundsCompleted()
        model.incrementRoundsCompleted()
        model.decrementRoundsCompleted()

        #expect(model.roundsCompleted == 1)
    }

    @Test @MainActor func decrementRoundsCompleted_doesNotGoBelowZero() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        model.decrementRoundsCompleted()

        #expect(model.roundsCompleted == 0)
    }

    @Test @MainActor func progress_startsAtOne() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.progress == 1.0)
    }

    @Test @MainActor func elapsedTime_startsAtZero() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.elapsedTime == 0)
    }

    // MARK: - Cross-device anchoring / pause-resume drift (ADR-003)

    /// Two independent models fed the SAME canonical pause/resume dates stay in sync across
    /// many cycles, even when the "phone" processes each event a fixed latency after the "Watch".
    @Test @MainActor func canonicalDatePauseResume_keepsDevicesInSync() {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let clock = { fakeNow }

        let watch = AMRAPTimerModel(
            totalDuration: 600,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )
        let phone = AMRAPTimerModel(
            totalDuration: 600,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )

        watch.start()
        phone.start()

        let latency: TimeInterval = 0.3
        for _ in 0..<20 {
            fakeNow += 1
            let pauseDate = fakeNow
            watch.pause(at: pauseDate)
            fakeNow += latency
            phone.pause(at: pauseDate)

            #expect(watch.totalTimeRemaining == phone.totalTimeRemaining)

            fakeNow += 1
            let resumeDate = fakeNow
            watch.resume(at: resumeDate)
            fakeNow += latency
            phone.resume(at: resumeDate)
        }

        fakeNow += 1
        let finalDate = fakeNow
        watch.pause(at: finalDate)
        phone.pause(at: finalDate)
        #expect(watch.totalTimeRemaining == phone.totalTimeRemaining)

        watch.reset()
        phone.reset()
    }

    /// Regression doc: re-anchoring resume from each device's LOCAL clock (`start()`) drifts and
    /// accumulates, unlike the canonical-date `resume(at:)`.
    @Test @MainActor func localClockResume_accumulatesDrift() {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let clock = { fakeNow }

        let watch = AMRAPTimerModel(
            totalDuration: 600,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )
        let phone = AMRAPTimerModel(
            totalDuration: 600,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )

        watch.start()
        phone.start()

        let latency: TimeInterval = 0.3
        for _ in 0..<20 {
            fakeNow += 1
            let pauseDate = fakeNow
            watch.pause(at: pauseDate)
            phone.pause(at: pauseDate)

            fakeNow += 1
            watch.start()
            fakeNow += latency
            phone.start()
        }

        fakeNow += 1
        let finalDate = fakeNow
        watch.pause(at: finalDate)
        phone.pause(at: finalDate)
        #expect(abs(watch.totalTimeRemaining - phone.totalTimeRemaining) > 2)

        watch.reset()
        phone.reset()
    }
}
