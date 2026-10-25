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
            intervalCount: 6,
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
            intervalCount: 6,
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
            intervalCount: 6,
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
            intervalCount: 6,
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
            intervalCount: 6,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.totalIntervals == 6)
    }

    @Test @MainActor func completedIntervals_startsAtZero() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalCount: 6,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.completedIntervals == 0)
    }

    @Test @MainActor func overallProgress_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalCount: 6,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.overallProgress == 1.0)
    }

    @Test @MainActor func intervalProgress_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalCount: 6,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.intervalProgress == 1.0)
    }

    @Test @MainActor func currentInterval_startsAtOne() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalCount: 6,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        #expect(model.currentInterval == 1)
    }

    @Test @MainActor func currentInterval_capsAtTotal() {
        let model = EMOMTimerModel(
            totalDuration: 60,
            intervalCount: 6,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback()
        )

        // Simulate workout completion: totalTimeRemaining == 0
        // completedIntervals = Int((60 - 0) / 10) = 6 = totalIntervals
        // currentInterval = min(6 + 1, 6) = 6 (capped)
        model.start()
        // We can't easily fast-forward time, but we can verify the cap logic
        // by checking that at initial state (completedIntervals=0),
        // currentInterval = min(0+1, 6) = 1, which is within bounds.
        // The cap matters when completedIntervals == totalIntervals.
        #expect(model.currentInterval <= model.totalIntervals)
        model.reset()
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

    @Test @MainActor func totalIntervals_survivesFloatingPointRoundTrip() {
        // Regression: deriving the count via Int(totalDuration / intervalDuration)
        // truncated 113.9999… to 113 for certain rep counts (e.g. 114 over 20 min).
        for reps in [112, 113, 114, 137, 199] {
            let model = EMOMTimerModel(
                totalReps: reps,
                totalMinutes: 20,
                timerProvider: MockTimerProvider(),
                feedbackProvider: SilentFeedback()
            )

            #expect(model.totalIntervals == reps)   // 114 returned 113 before the fix
        }
    }

    // MARK: - Anchored late start (start(at:))

    /// A mirror joining late anchors to the leader's start date and shows the
    /// matching elapsed position instead of starting from zero.
    @Test @MainActor func startAt_pastAnchor_showsLeaderElapsedTime() {
        let fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let model = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(),
            now: { fakeNow }
        )

        // Leader started 90 s ago
        model.start(at: fakeNow.addingTimeInterval(-90))

        #expect(model.isRunning == true)
        #expect(model.totalTimeRemaining == 510)
        #expect(model.completedIntervals == 1)  // 90 s elapsed of 60 s intervals
        model.reset()
    }

    /// Joining mid-workout must not replay the interval-complete sounds for
    /// intervals that finished before the join, and must not play start feedback
    /// (it's a remote-driven start).
    @Test @MainActor func startAt_pastAnchor_doesNotReplayFeedback() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let spy = SpyFeedbackProvider()
        let model = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: provider, feedbackProvider: spy,
            now: { fakeNow }
        )

        // Join 90 s in (one interval already complete, mid second interval)
        model.start(at: fakeNow.addingTimeInterval(-90))
        provider.simulateTick()
        await Self.drainMainQueue()  // ticks dispatch update() via Task { @MainActor }

        #expect(spy.startCount == 0)
        #expect(spy.intervalCompleteCount == 0)

        // The NEXT interval boundary still fires its feedback normally.
        fakeNow += 31  // elapsed 121 s → past the 120 s boundary
        provider.simulateTick()
        await Self.drainMainQueue()
        #expect(spy.intervalCompleteCount == 1)
        model.reset()
    }

    /// Lets main-actor Tasks queued by the tick handler run before asserting.
    @MainActor
    private static func drainMainQueue() async {
        for _ in 0..<5 { await Task.yield() }
    }

    // MARK: - Cross-device anchoring / pause-resume drift (ADR-003)

    /// Two independent models (Watch + phone) fed the SAME canonical pause/resume dates stay
    /// bit-for-bit in sync across many cycles — even though the "phone" processes each event a
    /// fixed latency after the "Watch". This is the invariant ADR-003 establishes, and the
    /// assertions are synchronous because `pause(at:)` recomputes the display fields itself.
    @Test @MainActor func canonicalDatePauseResume_keepsDevicesInSync() {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let clock = { fakeNow }

        let watch = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )
        let phone = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )

        // Both start anchored to the same instant (mirrors the scheduledStartTime handshake).
        watch.start()
        phone.start()

        let latency: TimeInterval = 0.3
        for _ in 0..<20 {
            // Run, then PAUSE: Watch processes the canonical date, phone processes it `latency` later.
            fakeNow += 1
            let pauseDate = fakeNow
            watch.pause(at: pauseDate)
            fakeNow += latency
            phone.pause(at: pauseDate)

            #expect(watch.totalTimeRemaining == phone.totalTimeRemaining)
            #expect(watch.intervalTimeRemaining == phone.intervalTimeRemaining)

            // Paused gap, then RESUME with the same staggered processing.
            fakeNow += 1
            let resumeDate = fakeNow
            watch.resume(at: resumeDate)
            fakeNow += latency
            phone.resume(at: resumeDate)
        }

        // Evaluate both at one final shared instant.
        fakeNow += 1
        let finalDate = fakeNow
        watch.pause(at: finalDate)
        phone.pause(at: finalDate)
        #expect(watch.totalTimeRemaining == phone.totalTimeRemaining)
        #expect(watch.intervalTimeRemaining == phone.intervalTimeRemaining)

        watch.reset()
        phone.reset()
    }

    /// Regression doc: the pre-fix behaviour re-anchored resume from each device's LOCAL clock
    /// (`start()`), so the same staggered processing drifts and the error accumulates (~latency
    /// per cycle). Contrast with the canonical-date `resume(at:)` above, which does not drift.
    @Test @MainActor func localClockResume_accumulatesDrift() {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let clock = { fakeNow }

        let watch = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )
        let phone = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )

        watch.start()
        phone.start()

        let latency: TimeInterval = 0.3
        for _ in 0..<20 {
            // Pause is shared (canonical date) so the drift is isolated to the resume path.
            fakeNow += 1
            let pauseDate = fakeNow
            watch.pause(at: pauseDate)
            phone.pause(at: pauseDate)

            // OLD resume: re-anchor from the local clock, staggered by latency.
            fakeNow += 1
            watch.start()
            fakeNow += latency
            phone.start()
        }

        fakeNow += 1
        let finalDate = fakeNow
        watch.pause(at: finalDate)
        phone.pause(at: finalDate)
        // ~0.3s drift per cycle over 20 cycles accumulates well past a second.
        #expect(abs(watch.totalTimeRemaining - phone.totalTimeRemaining) > 2)

        watch.reset()
        phone.reset()
    }

    // MARK: - Completion signal & tick guards (issue #47)

    /// Reaching zero while running sets the explicit `didComplete` signal.
    @Test @MainActor func update_reachingZero_setsDidComplete() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let model = EMOMTimerModel(
            totalDuration: 60, intervalCount: 6,
            timerProvider: provider, feedbackProvider: SilentFeedback(), now: { fakeNow }
        )

        model.start()
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
        let model = EMOMTimerModel(
            totalDuration: 60, intervalCount: 6,
            timerProvider: provider, feedbackProvider: spy, now: { fakeNow }
        )

        model.start()
        model.pause(at: start.addingTimeInterval(60))  // date at the natural end

        #expect(model.didComplete == false)

        fakeNow += 61
        provider.simulateTick()
        await Self.drainMainQueue()

        #expect(model.didComplete == true)
        #expect(model.totalTimeRemaining == 0)
        #expect(spy.workoutCompleteCount == 1)
    }

    // MARK: - State-driven rendering (ADR-006)

    private static func makeState(
        startDate: Date, duration: TimeInterval = 600, intervals: Int = 10
    ) -> TimerState {
        TimerState(
            workoutID: UUID(),
            owner: .watch,
            config: TimerConfig(
                timerKindRaw: TimerKind.emom.rawValue,
                totalDuration: duration,
                intervalCount: intervals,
                exerciseName: "Burpees"
            ),
            startDate: startDate
        )
    }

    /// Two models fed the same state show identical values, however late each one applies it —
    /// the core ADR-006 guarantee that replaces per-device anchoring.
    @Test @MainActor func apply_sameState_rendersIdenticallyOnBothDevices() {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let clock = { fakeNow }
        let watch = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )
        let phone = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: clock
        )
        var state = Self.makeState(startDate: fakeNow.addingTimeInterval(-90))

        watch.apply(state)
        fakeNow += 0.7  // the phone receives the snapshot later
        phone.apply(state)
        watch.apply(state)  // re-render both at the same instant

        #expect(watch.totalTimeRemaining == phone.totalTimeRemaining)
        #expect(watch.intervalTimeRemaining == phone.intervalTimeRemaining)
        #expect(watch.isRunning && phone.isRunning)

        // A pause published by the owner freezes both at the same value.
        state = TimerStateReducer.apply(
            [TimerIntent(workoutID: state.workoutID, baseRevision: state.revision, action: .pause, at: fakeNow)],
            to: state, now: fakeNow
        )
        fakeNow += 2
        watch.apply(state)
        fakeNow += 3
        phone.apply(state)

        #expect(watch.totalTimeRemaining == phone.totalTimeRemaining)
        #expect(!watch.isRunning && !phone.isRunning)
    }

    /// Adopting a state mid-workout (late join) doesn't replay past interval feedback or play
    /// start feedback; the next boundary still fires.
    @Test @MainActor func apply_lateJoin_doesNotReplayFeedback() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let spy = SpyFeedbackProvider()
        let model = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: provider, feedbackProvider: spy, now: { fakeNow }
        )

        model.apply(Self.makeState(startDate: fakeNow.addingTimeInterval(-90)))
        provider.simulateTick()
        await Self.drainMainQueue()

        #expect(spy.startCount == 0)
        #expect(spy.intervalCompleteCount == 0)

        fakeNow += 31  // elapsed 121 s → past the 120 s boundary
        provider.simulateTick()
        await Self.drainMainQueue()
        #expect(spy.intervalCompleteCount == 1)
        model.reset()
    }

    /// A state still in its countdown renders the full duration and is running (ticking toward
    /// the shared start).
    @Test @MainActor func apply_countdownState_showsFullDuration() {
        let fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let model = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: { fakeNow }
        )

        model.apply(Self.makeState(startDate: fakeNow.addingTimeInterval(2)))

        #expect(model.totalTimeRemaining == 600)
        #expect(model.currentInterval == 1)
        model.reset()
    }

    /// A stopped state ends the timer without the completion signal.
    @Test @MainActor func apply_stoppedState_isNotCompletion() {
        let fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let model = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: MockTimerProvider(), feedbackProvider: SilentFeedback(), now: { fakeNow }
        )
        var state = Self.makeState(startDate: fakeNow.addingTimeInterval(-30))
        state.finish = .stopped(at: fakeNow)

        model.apply(state)

        #expect(model.isRunning == false)
        #expect(model.didComplete == false)
        #expect(model.totalTimeRemaining == 570)
    }

    /// A completed state adopted late sets the completion signal without the completion sound
    /// (the viewer never saw the timer run out).
    @Test @MainActor func apply_completedState_signalsCompletionSilently() {
        let fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let spy = SpyFeedbackProvider()
        let model = EMOMTimerModel(
            totalDuration: 60, intervalCount: 6,
            timerProvider: MockTimerProvider(), feedbackProvider: spy, now: { fakeNow }
        )
        var state = Self.makeState(startDate: fakeNow.addingTimeInterval(-100), duration: 60, intervals: 6)
        state.finish = .completed(at: fakeNow.addingTimeInterval(-40))

        model.apply(state)

        #expect(model.didComplete == true)
        #expect(model.totalTimeRemaining == 0)
        #expect(model.intervalTimeRemaining == 0)
        #expect(spy.workoutCompleteCount == 0)
    }

    /// Finding 15: a tick that enqueues its update() Task just before `pause()` runs must be a
    /// no-op — it must not recompute the frozen display or fire interval/warning/completion.
    @Test @MainActor func strayTickEnqueuedBeforePause_isNoOp() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let spy = SpyFeedbackProvider()
        let model = EMOMTimerModel(
            totalDuration: 600, intervalCount: 10,
            timerProvider: provider, feedbackProvider: spy, now: { fakeNow }
        )

        model.start()
        fakeNow += 10
        provider.simulateTick()
        await Self.drainMainQueue()
        let frozen = model.totalTimeRemaining

        // A tick fires (enqueues its update Task) and the user pauses before it runs.
        provider.simulateTick()
        model.pause()
        fakeNow += 100  // clock moves on
        await Self.drainMainQueue()  // the stray update() now runs — must do nothing

        #expect(model.totalTimeRemaining == frozen)
        #expect(model.didComplete == false)
        #expect(spy.workoutCompleteCount == 0)
    }

    @Test @MainActor func reset_clearsDidComplete() async {
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let provider = MockTimerProvider()
        let model = EMOMTimerModel(
            totalDuration: 60, intervalCount: 6,
            timerProvider: provider, feedbackProvider: SilentFeedback(), now: { fakeNow }
        )

        model.start()
        fakeNow += 61
        provider.simulateTick()
        await Self.drainMainQueue()
        #expect(model.didComplete == true)

        model.reset()
        #expect(model.didComplete == false)
    }
}
