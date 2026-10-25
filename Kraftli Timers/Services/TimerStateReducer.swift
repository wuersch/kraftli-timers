//
//  TimerStateReducer.swift
//  Kraftli Timers
//
//  The single place where a `TimerState` changes (ADR-006 / ADR-007).
//  Shared by the iPhone and Watch targets.
//
//  ## What a reducer is
//  A reducer is a pure function `(state, input) -> newState`: no side effects,
//  no clock reads, no I/O. The caller passes in `now`. That makes it:
//  - deterministic — the same inputs always give the same output, so it can be
//    unit-tested exhaustively without devices or timers;
//  - shareable — the owner uses it to apply intents for real, and the viewer
//    uses the *same* function to predict the result of its own pending intents,
//    so a prediction can only differ from the owner's answer when the owner
//    really had a conflicting change.
//
//  The owner routes its own taps through here too (as intents against its
//  current revision), so local and remote actions follow identical rules.
//

import Foundation

nonisolated enum TimerStateReducer {

    // MARK: - Intents

    /// Applies a batch of intents and returns the resulting state.
    ///
    /// Rules (ADR-007):
    /// - Intents for another workout, or already handled ones, are ignored.
    /// - **Pause/resume** are rejected if the owner's paused/running state changed
    ///   after the intent's base revision — the owner's state wins — unless that
    ///   change was the sender's own preceding pause/resume (`previousPauseIntentID`).
    /// - **Rounds** and **stop** are always honored (rounds commute; stopping is
    ///   never wrong), subject only to the workout not having ended before them.
    /// - An action that doesn't fit the current state (pausing a paused timer,
    ///   pausing during the countdown) is a no-op.
    ///
    /// Every processed intent — applied or rejected — is recorded in
    /// `handledIntentIDs`. If anything changed, `revision` is incremented exactly once.
    ///
    /// - Parameters:
    ///   - intents: In the order the user made them.
    ///   - state: The current state.
    ///   - now: The current time on the applying device.
    static func apply(_ intents: [TimerIntent], to state: TimerState, now: Date) -> TimerState {
        let fresh = intents.filter {
            $0.workoutID == state.workoutID && !state.handledIntentIDs.contains($0.id)
        }
        guard !fresh.isEmpty else { return state }

        var next = state
        let nextRevision = state.revision + 1
        for intent in fresh {
            switch intent.action {
            case .pause, .resume:
                guard !conflicts(intent, with: next) else {
                    break  // Rejected: the owner's paused/running state changed meanwhile.
                }
                let wasPaused = next.isPaused
                if intent.action == .pause {
                    pause(&next, at: intent.at, now: now)
                } else {
                    resume(&next, at: intent.at, now: now)
                }
                if next.isPaused != wasPaused {
                    next.pauseStateRevision = nextRevision
                    next.pauseStateIntentID = intent.id
                }
            case .incrementRound:
                incrementRound(&next, at: intent.at, now: now)
            case .stop:
                stop(&next, at: intent.at, now: now)
            }
        }

        next.handledIntentIDs = Array((state.handledIntentIDs + fresh.map(\.id)).suffix(TimerState.handledIntentIDLimit))
        next.revision = nextRevision
        return next
    }

    /// A pause/resume conflicts when the paused/running state changed after the sender's
    /// base revision — unless the change was the sender's own preceding intent.
    private static func conflicts(_ intent: TimerIntent, with state: TimerState) -> Bool {
        guard intent.baseRevision < state.pauseStateRevision else { return false }
        if let previous = intent.previousPauseIntentID, previous == state.pauseStateIntentID {
            return false
        }
        return true
    }

    // MARK: - Completion

    /// Marks the workout completed once its time has run out.
    ///
    /// Called by the owner on its tick. Returns nil when nothing changes, so the
    /// caller only publishes a new revision when the workout actually finished.
    static func completingIfDue(_ state: TimerState, now: Date) -> TimerState? {
        guard state.finish == nil, !state.isPaused,
              state.elapsed(at: now) >= state.config.totalDuration else {
            return nil
        }
        var next = state
        let endDate = state.startDate
            .addingTimeInterval(state.accumulatedPause + state.config.totalDuration)
        next.finish = .completed(at: endDate)
        next.revision = state.revision + 1
        return next
    }

    // MARK: - Actions

    /// The time an action takes effect: the tap time, clamped so it neither precedes
    /// the last transition (no rewriting history) nor lies in the future (clock skew).
    private static func effectiveDate(_ date: Date, in state: TimerState, now: Date) -> Date {
        min(max(date, state.lastTransitionAt), now)
    }

    private static func pause(_ state: inout TimerState, at date: Date, now: Date) {
        guard state.finish == nil, !state.isPaused else { return }
        let effective = effectiveDate(date, in: state, now: now)
        // No pausing during the countdown or after the time has run out.
        guard effective >= state.startDate,
              state.elapsed(at: effective) < state.config.totalDuration else { return }
        state.pausedAt = effective
        state.lastTransitionAt = effective
    }

    private static func resume(_ state: inout TimerState, at date: Date, now: Date) {
        guard state.finish == nil, let pausedAt = state.pausedAt else { return }
        let effective = effectiveDate(date, in: state, now: now)
        state.accumulatedPause += effective.timeIntervalSince(pausedAt)
        state.pausedAt = nil
        state.lastTransitionAt = effective
    }

    private static func incrementRound(_ state: inout TimerState, at date: Date, now: Date) {
        // Count a round tapped while the workout was live, even if the intent arrives
        // after the timer reached zero — but not one tapped after the workout ended.
        guard !state.isCountingDown(at: date), endDate(of: state).map({ date < $0 }) ?? true else { return }
        state.roundCount += 1
    }

    private static func stop(_ state: inout TimerState, at date: Date, now: Date) {
        guard state.finish == nil else { return }
        // A stop arriving after the time already ran out records the natural completion.
        if let completed = completingIfDue(state, now: min(date, now)) {
            state.finish = completed.finish
            return
        }
        state.finish = .stopped(at: effectiveDate(date, in: state, now: now))
    }

    /// The instant the workout ended or will end, if known (nil while paused and unfinished).
    private static func endDate(of state: TimerState) -> Date? {
        if let finish = state.finish { return finish.date }
        guard !state.isPaused else { return nil }
        return state.startDate.addingTimeInterval(state.accumulatedPause + state.config.totalDuration)
    }
}
