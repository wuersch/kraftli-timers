//
//  TimerStateTests.swift
//  Kraftli TimersTests
//
//  Tests for the replicated timer state and its reducer (ADR-006 / ADR-007).
//  All times are absolute offsets from a fixed `t0`, so every case is deterministic.
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct TimerStateTests {

    // MARK: - Fixtures

    /// Countdown begins at t0; the workout clock starts at t0 + 3 s.
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let workoutID = UUID()

    private func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    private func makeState(duration: TimeInterval = 600) -> TimerState {
        TimerState(
            workoutID: workoutID,
            owner: .watch,
            config: TimerConfig(
                timerKindRaw: TimerKind.amrap.rawValue,
                totalDuration: duration,
                intervalCount: nil,
                exerciseName: "Burpees"
            ),
            now: t0
        )
    }

    private func intent(
        _ action: TimerIntent.Action,
        at seconds: TimeInterval,
        base: Int,
        workoutID: UUID? = nil
    ) -> TimerIntent {
        TimerIntent(workoutID: workoutID ?? self.workoutID, baseRevision: base, action: action, at: at(seconds))
    }

    /// Applies one intent based on the state's current revision (no conflict).
    private func applying(
        _ action: TimerIntent.Action,
        at seconds: TimeInterval,
        to state: TimerState,
        now: TimeInterval? = nil
    ) -> TimerState {
        TimerStateReducer.apply(
            [intent(action, at: seconds, base: state.revision)],
            to: state,
            now: at(now ?? seconds)
        )
    }

    // MARK: - New state & countdown

    @Test func newState_startsAfterSharedCountdown() {
        let state = makeState()

        #expect(state.revision == 1)
        #expect(state.startDate == at(TimerState.countdownDuration))
        #expect(state.isCountingDown(at: at(2.9)))
        #expect(!state.isCountingDown(at: at(3)))
        #expect(state.elapsed(at: at(1)) == 0)
        #expect(state.remaining(at: at(1)) == 600)
    }

    @Test func elapsed_runsFromStartDate() {
        let state = makeState()

        #expect(state.elapsed(at: at(13)) == 10)
        #expect(state.isRunning(at: at(13)))
    }

    @Test func elapsed_clampsAtTotalDuration() {
        let state = makeState(duration: 60)

        #expect(state.elapsed(at: at(500)) == 60)
        #expect(state.remaining(at: at(500)) == 0)
        #expect(state.isFinished(at: at(500)))
        #expect(!state.isRunning(at: at(500)))
    }

    // MARK: - Pause / resume

    @Test func pause_freezesElapsedAtTapTime() {
        let paused = applying(.pause, at: 13, to: makeState())

        #expect(paused.isPaused)
        #expect(paused.elapsed(at: at(13)) == 10)
        #expect(paused.elapsed(at: at(100)) == 10)
        #expect(paused.revision == 2)
        #expect(paused.pauseStateRevision == 2)
    }

    @Test func resume_excludesPausedTime() {
        let paused = applying(.pause, at: 13, to: makeState())
        let resumed = applying(.resume, at: 23, to: paused)

        #expect(!resumed.isPaused)
        #expect(resumed.accumulatedPause == 10)
        #expect(resumed.elapsed(at: at(33)) == 20)
    }

    @Test func pause_appliesAtTapTime_evenWhenDeliveredLate() {
        // The viewer tapped at 13 s; the intent reaches the owner at 15 s.
        let paused = applying(.pause, at: 13, to: makeState(), now: 15)

        #expect(paused.elapsed(at: at(15)) == 10)
    }

    @Test func pause_fromFutureClock_isClampedToNow() {
        // The viewer's clock runs 2 s ahead of the owner's.
        let paused = applying(.pause, at: 15, to: makeState(), now: 13)

        #expect(paused.pausedAt == at(13))
    }

    @Test func pause_cannotPrecedeLastTransition() {
        let paused = applying(.pause, at: 13, to: makeState())
        let resumed = applying(.resume, at: 23, to: paused)
        // A pause stamped before the resume can't rewrite the earlier cycle.
        let pausedAgain = applying(.pause, at: 20, to: resumed, now: 30)

        #expect(pausedAgain.pausedAt == at(23))
    }

    @Test func pause_duringCountdown_isNoOp() {
        let state = applying(.pause, at: 1, to: makeState())

        #expect(!state.isPaused)
    }

    @Test func pause_whilePaused_isNoOpButHandled() {
        let first = applying(.pause, at: 13, to: makeState())
        let duplicateTap = intent(.pause, at: 14, base: first.revision)
        let second = TimerStateReducer.apply([duplicateTap], to: first, now: at(14))

        #expect(second.pausedAt == at(13))
        #expect(second.handledIntentIDs.contains(duplicateTap.id))
        #expect(second.revision == first.revision + 1)
        #expect(second.pauseStateRevision == first.pauseStateRevision)
    }

    // MARK: - Dedup & filtering

    @Test func sameIntentTwice_isAppliedOnce() {
        let round = intent(.incrementRound, at: 13, base: 1)
        let once = TimerStateReducer.apply([round], to: makeState(), now: at(13))
        let twice = TimerStateReducer.apply([round], to: once, now: at(14))

        #expect(once.roundCount == 1)
        #expect(twice == once)
    }

    @Test func intentForOtherWorkout_isIgnored() {
        let state = makeState()
        let foreign = intent(.pause, at: 13, base: 1, workoutID: UUID())

        #expect(TimerStateReducer.apply([foreign], to: state, now: at(13)) == state)
    }

    @Test func handledIntentIDs_areBounded() {
        var state = makeState()
        for second in 0..<(TimerState.handledIntentIDLimit + 10) {
            state = applying(.incrementRound, at: 4 + Double(second), to: state)
        }

        #expect(state.handledIntentIDs.count == TimerState.handledIntentIDLimit)
        #expect(state.roundCount == TimerState.handledIntentIDLimit + 10)
    }

    // MARK: - Conflicts (owner wins)

    @Test func stalePause_isRejected_whenOwnerPausedMeanwhile() {
        // Owner pauses at 13 and resumes at 20 (revisions 2, 3).
        let paused = applying(.pause, at: 13, to: makeState())
        let resumed = applying(.resume, at: 20, to: paused)
        // The disconnected viewer, still at revision 1, paused at 18.
        let viewerPause = intent(.pause, at: 18, base: 1)

        let result = TimerStateReducer.apply([viewerPause], to: resumed, now: at(25))

        #expect(!result.isPaused)
        #expect(result.handledIntentIDs.contains(viewerPause.id))
    }

    @Test func stalePause_isApplied_whenOwnerOnlyCountedRounds() {
        // Owner counts a round at 10 (revision 2) — no pause-state change.
        let withRound = applying(.incrementRound, at: 10, to: makeState())
        let viewerPause = intent(.pause, at: 13, base: 1)

        let result = TimerStateReducer.apply([viewerPause], to: withRound, now: at(14))

        #expect(result.isPaused)
        #expect(result.roundCount == 1)
    }

    @Test func staleRound_isAlwaysApplied() {
        let paused = applying(.pause, at: 13, to: makeState())
        let staleRound = intent(.incrementRound, at: 12, base: 1)

        let result = TimerStateReducer.apply([staleRound], to: paused, now: at(14))

        #expect(result.roundCount == 1)
    }

    @Test func offlineBatch_pauseThenResume_appliesBoth() {
        let pause = intent(.pause, at: 13, base: 1)
        let batch = [
            pause,
            TimerIntent(workoutID: workoutID, baseRevision: 1, action: .resume, at: at(23), previousPauseIntentID: pause.id),
        ]

        let result = TimerStateReducer.apply(batch, to: makeState(), now: at(30))

        #expect(!result.isPaused)
        #expect(result.accumulatedPause == 10)
        #expect(result.revision == 2)
    }

    @Test func offlineBatch_isRejectedAsAWhole_onConflict() {
        let ownerPaused = applying(.pause, at: 11, to: makeState())
        let viewerPause = intent(.pause, at: 13, base: 1)
        let batch = [
            viewerPause,
            TimerIntent(workoutID: workoutID, baseRevision: 1, action: .resume, at: at(23), previousPauseIntentID: viewerPause.id),
            intent(.incrementRound, at: 12, base: 1),
        ]

        let result = TimerStateReducer.apply(batch, to: ownerPaused, now: at(30))

        // Pause/resume rejected (owner stays paused at 11); the round still counts.
        #expect(result.pausedAt == at(11))
        #expect(result.roundCount == 1)
        #expect(result.handledIntentIDs.count == 4)
    }

    /// Queued intents may arrive in separate deliveries: the viewer's resume, chained to its
    /// own already-applied pause, must not be mistaken for a conflict.
    @Test func chainedResume_arrivingSeparately_isNotAConflict() {
        let viewerPause = intent(.pause, at: 13, base: 1)
        let viewerResume = TimerIntent(
            workoutID: workoutID, baseRevision: 1, action: .resume, at: at(23),
            previousPauseIntentID: viewerPause.id
        )

        let paused = TimerStateReducer.apply([viewerPause], to: makeState(), now: at(14))
        let resumed = TimerStateReducer.apply([viewerResume], to: paused, now: at(30))

        #expect(!resumed.isPaused)
        #expect(resumed.accumulatedPause == 10)
    }

    /// A chained resume is still rejected if the owner changed the pause state after the
    /// viewer's own pause.
    @Test func chainedResume_isRejected_whenOwnerChangedPauseStateSince() {
        let viewerPause = intent(.pause, at: 13, base: 1)
        let viewerResume = TimerIntent(
            workoutID: workoutID, baseRevision: 1, action: .resume, at: at(30),
            previousPauseIntentID: viewerPause.id
        )
        let paused = TimerStateReducer.apply([viewerPause], to: makeState(), now: at(14))
        let ownerResumed = applying(.resume, at: 20, to: paused)
        let ownerPaused = applying(.pause, at: 25, to: ownerResumed)

        let result = TimerStateReducer.apply([viewerResume], to: ownerPaused, now: at(31))

        #expect(result.pausedAt == at(25))
    }

    @Test func viewerPrediction_matchesOwnerResult() {
        // The viewer predicts with the same reducer, from the same confirmed state.
        let confirmed = makeState()
        let pending = [intent(.pause, at: 13, base: confirmed.revision)]

        let predicted = TimerStateReducer.apply(pending, to: confirmed, now: at(13))
        let ownerResult = TimerStateReducer.apply(pending, to: confirmed, now: at(15))

        #expect(predicted.elapsed(at: at(40)) == ownerResult.elapsed(at: at(40)))
    }

    // MARK: - Rounds

    @Test func round_duringCountdown_isNotCounted() {
        #expect(applying(.incrementRound, at: 1, to: makeState()).roundCount == 0)
    }

    @Test func round_tappedBeforeEnd_countsEvenIfDeliveredAfter() {
        let state = makeState(duration: 60)  // Ends at 63 s.
        let lateRound = intent(.incrementRound, at: 62, base: 1)

        let result = TimerStateReducer.apply([lateRound], to: state, now: at(70))

        #expect(result.roundCount == 1)
    }

    @Test func round_tappedAfterEnd_isNotCounted() {
        let state = makeState(duration: 60)

        #expect(applying(.incrementRound, at: 64, to: state, now: 64).roundCount == 0)
    }

    // MARK: - Stop

    @Test func stop_finishesAtTapTime() {
        let stopped = applying(.stop, at: 13, to: makeState(), now: 15)

        #expect(stopped.finish == .stopped(at: at(13)))
        #expect(stopped.elapsed(at: at(100)) == 10)
        #expect(stopped.isFinished(at: at(14)))
    }

    @Test func stop_whilePaused_keepsPausedElapsed() {
        let paused = applying(.pause, at: 13, to: makeState())
        let stopped = applying(.stop, at: 30, to: paused)

        #expect(stopped.elapsed(at: at(100)) == 10)
    }

    @Test func stop_isHonoredEvenWhenStale() {
        let paused = applying(.pause, at: 13, to: makeState())
        let staleStop = intent(.stop, at: 20, base: 1)

        let result = TimerStateReducer.apply([staleStop], to: paused, now: at(21))

        #expect(result.finish != nil)
    }

    @Test func stop_afterTimeRanOut_recordsCompletion() {
        let state = makeState(duration: 60)

        let result = applying(.stop, at: 70, to: state)

        #expect(result.finish == .completed(at: at(63)))
    }

    @Test func secondStop_isNoOp() {
        let stopped = applying(.stop, at: 13, to: makeState())
        let again = applying(.stop, at: 20, to: stopped)

        #expect(again.finish == .stopped(at: at(13)))
    }

    // MARK: - Completion

    @Test func completingIfDue_beforeEnd_returnsNil() {
        #expect(TimerStateReducer.completingIfDue(makeState(duration: 60), now: at(30)) == nil)
    }

    @Test func completingIfDue_atEnd_setsCompletionAtExactEndTime() {
        let paused = applying(.pause, at: 13, to: makeState(duration: 60))
        let resumed = applying(.resume, at: 23, to: paused)  // 10 s paused → ends at 73 s.

        let completed = TimerStateReducer.completingIfDue(resumed, now: at(75))

        #expect(completed?.finish == .completed(at: at(73)))
        #expect(completed?.revision == resumed.revision + 1)
    }

    @Test func completingIfDue_whilePaused_returnsNil() {
        let paused = applying(.pause, at: 13, to: makeState(duration: 60))

        #expect(TimerStateReducer.completingIfDue(paused, now: at(500)) == nil)
    }

    // MARK: - Coding

    @Test func state_roundTripsThroughJSON() throws {
        let original = applying(.pause, at: 13, to: makeState())

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TimerState.self, from: data)

        #expect(decoded == original)
    }
}
