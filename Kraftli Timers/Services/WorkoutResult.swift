//
//  WorkoutResult.swift
//  Kraftli Timers
//
//  What a workout achieved. Shared by the iPhone and Watch targets.
//

import Foundation

/// What a workout achieved: the active time to record, and its count.
///
/// The one description of a result, whether it comes from a completed timer
/// (`TimerModel.result`) or from a workout stopped early (`EarlyStop`). History entries
/// (`WorkoutLog`) and completion reports (`WorkoutCompletionData`) are built from it.
nonisolated struct WorkoutResult: Equatable, Sendable {
    /// Active time in seconds, pauses excluded.
    let duration: TimeInterval
    /// EMOM: intervals done (one rep each). For Time: the target reps, once done.
    var reps: Int? = nil
    /// AMRAP: rounds counted.
    var rounds: Int? = nil
}
