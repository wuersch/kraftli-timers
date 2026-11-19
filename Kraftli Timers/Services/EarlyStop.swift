//
//  EarlyStop.swift
//  Kraftli Timers
//
//  What becomes of a workout that was ended early (UC-0005 extensions 1a–1b).
//

import Foundation

/// What to do with a workout that was ended before it completed.
///
/// A pure rule over the timer's state, so the iPhone and the Watch decide alike and the
/// rule is tested without a view: the iPhone asks it whether to write a history entry,
/// the Watch whether to save or discard its Health workout.
nonisolated enum EarlyStop: Equatable {
    /// Ended during the countdown or with too little active time: nothing is recorded,
    /// neither in the history nor in Apple Health (1b).
    case discard

    /// Recorded as stopped early, with the active time and the count so far (1a).
    /// A For Time workout has no rep count, because the reps done are unknown.
    case record(activeTime: TimeInterval, reps: Int?, rounds: Int?)

    /// The active time, pauses excluded, from which an early stop is recorded.
    static let minimumActiveTime: TimeInterval = 60

    /// The outcome for a workout ended at `now`, or at the moment its state says it was
    /// stopped. `nil` when the workout wasn't stopped early: it completed.
    init?(of state: TimerState, at now: Date) {
        if case .completed = state.finish { return nil }
        guard !state.hasRunOut(at: now) else { return nil }

        // Whole seconds, as a history entry holds them. `elapsed` excludes pauses and
        // is frozen at the stop.
        let activeTime = state.elapsed(at: now).rounded(.down)
        guard activeTime >= Self.minimumActiveTime else {
            self = .discard
            return
        }

        switch state.config.kind {
        case .emom:
            self = .record(activeTime: activeTime, reps: Self.completedIntervals(of: state.config, in: activeTime), rounds: nil)
        case .amrap:
            self = .record(activeTime: activeTime, reps: nil, rounds: state.roundCount)
        case .forTime:
            self = .record(activeTime: activeTime, reps: nil, rounds: nil)
        }
    }

    /// The EMOM intervals fully done within `activeTime`: one rep each.
    private static func completedIntervals(of config: TimerConfig, in activeTime: TimeInterval) -> Int {
        guard let totalDuration = config.totalDuration, let intervalCount = config.intervalCount,
              totalDuration > 0, intervalCount > 0 else { return 0 }
        let intervalLength = totalDuration / Double(intervalCount)
        return min(Int(activeTime / intervalLength), intervalCount)
    }
}
