//
//  ForTimeTests.swift
//  Kraftli TimersTests
//
//  Tests for open-ended (For Time) workouts: the reducer's `done` intent (ADR-0010),
//  the For Time timer model, and its presets, logs and summary.
//  All times are absolute offsets from a fixed `t0`, so every case is deterministic.
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct ForTimeTests {

    // MARK: - Fixtures

    /// Countdown begins at t0; the workout clock starts at t0 + 3 s.
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let workoutID = UUID()

    private func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    private func makeState(totalDuration: TimeInterval? = nil) -> TimerState {
        TimerState(
            workoutID: workoutID,
            owner: .phone,
            config: TimerConfig(
                kind: totalDuration == nil ? .forTime : .amrap,
                totalDuration: totalDuration,
                intervalCount: nil,
                exerciseName: "Burpees",
                targetReps: totalDuration == nil ? 50 : nil
            ),
            now: t0
        )
    }

    /// Applies one intent based on the state's current revision (no conflict).
    private func applying(
        _ action: TimerIntent.Action,
        at seconds: TimeInterval,
        to state: TimerState,
        now: TimeInterval? = nil
    ) -> TimerState {
        TimerStateReducer.apply(
            [TimerIntent(workoutID: workoutID, baseRevision: state.revision, action: action, at: at(seconds))],
            to: state,
            now: at(now ?? seconds)
        )
    }

    // MARK: - Open-ended state

    @Test func openEnded_elapsedIsNotClampedAndNeverRunsOut() {
        let state = makeState()

        // Hours after the start, the clock is still counting and the workout isn't finished.
        #expect(state.elapsed(at: at(3 + 7200)) == 7200)
        #expect(state.remaining(at: at(100)) == nil)
        #expect(!state.isFinished(at: at(3 + 7200)))
        #expect(state.isRunning(at: at(3 + 7200)))
    }

    @Test func openEnded_neverCompletesByItself() {
        let state = makeState()

        #expect(TimerStateReducer.completingIfDue(state, now: at(3 + 36_000)) == nil)
    }

    // MARK: - Done intent

    @Test func done_completesAtTheTapTime() {
        let state = applying(.done, at: 3 + 125, to: makeState())

        #expect(state.finish == .completed(at: at(3 + 125)))
        #expect(state.elapsed(at: at(3 + 500)) == 125)
        #expect(state.revision == 2)
    }

    @Test func done_arrivingLate_keepsTheDeclaredMoment() {
        // Declared on the viewer at 128 s, applied by the owner 2 s later.
        let state = applying(.done, at: 3 + 128, to: makeState(), now: 3 + 130)

        #expect(state.finish == .completed(at: at(3 + 128)))
    }

    @Test func done_excludesPauses() {
        var state = applying(.pause, at: 3 + 60, to: makeState())
        state = applying(.resume, at: 3 + 90, to: state)
        state = applying(.done, at: 3 + 150, to: state)

        #expect(state.elapsed(at: at(3 + 500)) == 120)
    }

    @Test func done_duringCountdown_isIgnored() {
        let state = applying(.done, at: 2, to: makeState())

        #expect(state.finish == nil)
    }

    @Test func done_whilePaused_isIgnored() {
        var state = applying(.pause, at: 3 + 60, to: makeState())
        state = applying(.done, at: 3 + 70, to: state)

        #expect(state.finish == nil)
        #expect(state.isPaused)
    }

    @Test func done_tappedBeforeOwnerPause_completesAtThePause() {
        // The viewer declared done at 62 s; the owner paused at 65 s before it arrived.
        var state = applying(.pause, at: 3 + 65, to: makeState())
        state = applying(.done, at: 3 + 62, to: state, now: 3 + 66)

        #expect(state.finish == .completed(at: at(3 + 65)))
        #expect(state.elapsed(at: at(3 + 500)) == 65)
        #expect(!state.isRunning(at: at(3 + 500)))
    }

    @Test func done_afterStop_isIgnored() {
        var state = applying(.stop, at: 3 + 60, to: makeState())
        state = applying(.done, at: 3 + 61, to: state)

        #expect(state.finish == .stopped(at: at(3 + 60)))
    }

    @Test func done_onTimeBoxedWorkout_isIgnored() {
        let state = applying(.done, at: 3 + 60, to: makeState(totalDuration: 600))

        #expect(state.finish == nil)
    }

    @Test func done_afterLaterPauseOnOwner_isClampedToThatPause() {
        // Accepted deviation from UC-0012 7b (ADR-0010): the owner paused at 65 s and resumed
        // at 70 s before a done declared at 62 s arrived; it's moved to the resume.
        var state = applying(.pause, at: 3 + 65, to: makeState())
        state = applying(.resume, at: 3 + 70, to: state)
        state = applying(.done, at: 3 + 62, to: state, now: 3 + 71)

        #expect(state.finish == .completed(at: at(3 + 70)))
    }

    @Test func stop_onOpenEndedWorkout_isNeverACompletion() {
        let state = applying(.stop, at: 3 + 7200, to: makeState())

        #expect(state.finish == .stopped(at: at(3 + 7200)))
    }

    @Test func done_survivesEncodingRoundTrip() throws {
        let intent = TimerIntent(workoutID: workoutID, baseRevision: 1, action: .done, at: at(10))
        let data = try JSONEncoder().encode(intent)
        #expect(try JSONDecoder().decode(TimerIntent.self, from: data) == intent)

        let state = makeState()
        let decoded = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
        #expect(decoded.config.totalDuration == nil)
        #expect(decoded.config.targetReps == 50)
    }

    // MARK: - Timer model

    @Test @MainActor func model_countsUpAndCompletesOnDone() {
        var now = at(3 + 42.7)
        let feedback = SpyFeedbackProvider()
        let model = ForTimeTimerModel(
            targetReps: 50,
            timerProvider: MockTimerProvider(),
            feedbackProvider: feedback,
            now: { now }
        )

        var state = makeState()
        model.apply(state)
        #expect(model.isRunning)
        #expect(abs(model.elapsedTime - 42.7) < 0.001)  // date arithmetic isn't exact
        #expect(!model.isCompleted)

        now = at(3 + 125.6)
        state = applying(.done, at: 3 + 125.6, to: state)
        model.apply(state)

        #expect(model.didComplete)
        #expect(model.isCompleted)
        #expect(!model.isRunning)
        #expect(model.finishTime == 125)  // whole seconds
        #expect(model.recordedDuration == 125)
        #expect(model.completedReps == 50)
        #expect(model.pace == 2.5)
        #expect(feedback.workoutCompleteCount == 1)
        #expect(feedback.intervalCompleteCount == 0)
        #expect(feedback.warningCount == 0)
        model.reset()
    }

    @Test @MainActor func model_stopIsNotACompletion() {
        let model = ForTimeTimerModel(
            targetReps: 100,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback(),
            now: { self.at(3 + 90) }
        )

        model.apply(applying(.stop, at: 3 + 90, to: makeState()))

        #expect(!model.didComplete)
        #expect(!model.isCompleted)
        #expect(!model.isRunning)
    }

    @Test @MainActor func model_finishTimeIsAtLeastOneSecond() {
        let model = ForTimeTimerModel(
            targetReps: 100,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback(),
            now: { self.at(3.4) }
        )

        model.apply(applying(.done, at: 3.4, to: makeState()))

        #expect(model.finishTime == 1)
    }

    @Test @MainActor func model_lapProgressWrapsEveryLap() {
        let model = ForTimeTimerModel(
            targetReps: 100,
            timerProvider: MockTimerProvider(),
            feedbackProvider: SilentFeedback(),
            now: { self.at(3 + 72.5) }
        )

        model.apply(makeState())

        // 72.5 s = 7 laps of 10 s + 2.5 s.
        #expect(abs(model.lapProgress - 0.25) < 0.001)
        model.reset()
    }

    // MARK: - Presets, logs, summary

    @Test func preset_hasNoDurationAndShowsReps() {
        let preset = TimerPreset(kind: .forTime, durationInterval: 0, targetReps: 100)

        #expect(preset.primaryText == "For Time")
        #expect(preset.secondaryText.contains("100 Reps"))
    }

    @Test func log_showsFinishTimeToTheSecond() {
        let log = WorkoutLog(exerciseName: "Burpees", timerKind: .forTime, durationSeconds: 272, repsCompleted: 100)

        #expect(log.formattedDuration == "4:32")
        #expect(log.summaryText == "4:32\(UISeparator.dot)100 reps")
    }

    @Test func summary_showsFinishTimeAndPace() {
        let summary = WorkoutSummaryData(
            exerciseName: "Burpees",
            timerKind: .forTime,
            duration: 420,
            reps: 100,
            rounds: nil,
            ownedByWatch: false
        )

        #expect(summary.durationTitle == "Finish Time")
        #expect(summary.formattedDuration == "7:00")
        // Locale-aware decimal separator ("4.2" or "4,2").
        #expect(summary.formattedPace == "\(4.2.formatted(.number.precision(.fractionLength(1)))) s/rep")
        #expect(summary.headerSubtitle == "For Time\(UISeparator.dot)100 reps")
    }
}
