//
//  WorkoutTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

/// What the timer views and lifecycle modifiers read from a timer model.
///
/// The models only *render* a workout: they adopt each `TimerState` via `apply(_:)`
/// (ADR-006). Starting, pausing and resuming go through `TimerSessionController`.
protocol WorkoutTimer: AnyObject {
    var isRunning: Bool { get }

    /// Whether the workout has ended as completed (time ran out, or For Time declared done).
    ///
    /// A protocol *requirement*, not just an extension method: requirements are dispatched
    /// dynamically to the conforming type, while a method that exists only in a protocol
    /// extension is chosen statically. Generic code such as `WatchTimerLifecycleModifier<T>`
    /// would otherwise always run the extension's version, never a model's own.
    var isCompleted: Bool { get }

    /// The active time to record when the workout completes: the full duration for the
    /// time-boxed kinds, the finish time for For Time.
    var recordedDuration: TimeInterval { get }

    /// Explicit completion signal: true once the workout's time ran out (observed on a tick, or
    /// adopted from a completed state) or For Time was declared done — never for a pause or a stop. Completion observers key
    /// off this rather than inferring it from `totalTimeRemaining`. Cleared by `reset()`.
    var didComplete: Bool { get }

    /// Reps completed (EMOM and For Time timers)
    var completedReps: Int? { get }
    /// Rounds completed (AMRAP timers)
    var completedRounds: Int? { get }

    func reset()
}
