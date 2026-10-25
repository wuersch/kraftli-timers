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

        let driver = StateDriver(amrap: model, now: { Date() })
        driver.start()

        #expect(model.isRunning == true)
        model.reset()
    }

    @Test @MainActor func pause_setsIsRunningFalse() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        let driver = StateDriver(amrap: model, now: { Date() })
        driver.start()
        driver.pause()

        #expect(model.isRunning == false)
        model.reset()
    }

    @Test @MainActor func reset_restoresInitialState() {
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        var state = TimerState(
            workoutID: UUID(),
            owner: .phone,
            config: TimerConfig(
                timerKindRaw: TimerKind.amrap.rawValue,
                totalDuration: 300,
                intervalCount: nil,
                exerciseName: "Pull-ups"
            ),
            startDate: Date().addingTimeInterval(-10)
        )
        state.roundCount = 2
        model.apply(state)
        #expect(model.roundsCompleted == 2)
        model.reset()

        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 300)
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

    // MARK: - Completion signal & tick guards (issue #47)

    /// Reaching zero while running sets the explicit `didComplete` signal.
    @Test @MainActor func update_reachingZero_setsDidComplete() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let model = AMRAPTimerModel(
            totalDuration: 60,
            timerProvider: provider, feedbackProvider: SilentFeedback(), now: { fakeNow }
        )

        let driver = StateDriver(amrap: model, now: { fakeNow })
        driver.start()
        #expect(model.didComplete == false)

        fakeNow += 61  // past the natural end
        provider.simulateTick()
        await Self.drainMainQueue()

        #expect(model.didComplete == true)
        #expect(model.isRunning == false)
        #expect(model.totalTimeRemaining == 0)
    }

    /// Finding 14, under ADR-006: a pause landing at/after the natural end is ignored by the
    /// reducer (the time had already run out), sets no completion by itself, and the next tick
    /// completes the workout normally — exactly once.
    @Test @MainActor func pauseAt_naturalEnd_isIgnored_andTickCompletes() async {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var fakeNow = start
        let provider = MockTimerProvider()
        let spy = SpyFeedbackProvider()
        let model = AMRAPTimerModel(
            totalDuration: 60,
            timerProvider: provider, feedbackProvider: spy, now: { fakeNow }
        )

        let driver = StateDriver(amrap: model, now: { fakeNow })
        driver.start()
        driver.pause(at: start.addingTimeInterval(60))  // date at the natural end

        #expect(model.didComplete == false)

        fakeNow += 61
        provider.simulateTick()
        await Self.drainMainQueue()

        #expect(model.didComplete == true)
        #expect(model.totalTimeRemaining == 0)
        #expect(spy.workoutCompleteCount == 1)
    }

    // MARK: - State-driven rendering (ADR-006)

    /// Adopting the owner's state shows its elapsed time and its round count.
    @Test @MainActor func apply_adoptsOwnerTimeAndRounds() {
        let fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let model = AMRAPTimerModel(
            totalDuration: 300,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: { fakeNow }
        )
        var state = TimerState(
            workoutID: UUID(),
            owner: .watch,
            config: TimerConfig(
                timerKindRaw: TimerKind.amrap.rawValue,
                totalDuration: 300,
                intervalCount: nil,
                exerciseName: "Pull-ups"
            ),
            startDate: fakeNow.addingTimeInterval(-90)
        )
        state.roundCount = 4

        model.apply(state)

        #expect(model.isRunning == true)
        #expect(model.totalTimeRemaining == 210)
        #expect(model.roundsCompleted == 4)
        model.reset()
    }

    /// Finding 15: a tick that enqueues its update() Task just before `pause()` runs must be a
    /// no-op — it must not recompute the frozen display from the clock or fire completion.
    @Test @MainActor func strayTickEnqueuedBeforePause_isNoOp() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let spy = SpyFeedbackProvider()
        let model = AMRAPTimerModel(
            totalDuration: 600,
            timerProvider: provider, feedbackProvider: spy, now: { fakeNow }
        )

        let driver = StateDriver(amrap: model, now: { fakeNow })
        driver.start()
        fakeNow += 10
        provider.simulateTick()
        await Self.drainMainQueue()
        let frozen = model.totalTimeRemaining  // 590

        // A tick fires (enqueues its update Task) and the user pauses before it runs.
        provider.simulateTick()
        driver.pause()
        fakeNow += 100  // clock moves on
        await Self.drainMainQueue()  // the stray update() now runs — must do nothing

        #expect(model.totalTimeRemaining == frozen)
        #expect(model.didComplete == false)
        #expect(spy.workoutCompleteCount == 0)
    }

    @Test @MainActor func reset_clearsDidComplete() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let model = AMRAPTimerModel(
            totalDuration: 60,
            timerProvider: provider, feedbackProvider: SilentFeedback(), now: { fakeNow }
        )

        let driver = StateDriver(amrap: model, now: { fakeNow })
        driver.start()
        fakeNow += 61
        provider.simulateTick()
        await Self.drainMainQueue()
        #expect(model.didComplete == true)

        model.reset()
        #expect(model.didComplete == false)
    }

    /// Lets main-actor Tasks queued by the tick handler run before asserting.
    @MainActor
    private static func drainMainQueue() async {
        for _ in 0..<5 { await Task.yield() }
    }
}
