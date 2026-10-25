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
    var totalTimeRemaining: TimeInterval { get }
    var totalDuration: TimeInterval { get }
    var isRunning: Bool { get }

    /// Explicit completion signal: true once the workout's time ran out (observed on a tick, or
    /// adopted from a completed state) — never for a pause or a stop. Completion observers key
    /// off this rather than inferring it from `totalTimeRemaining`. Cleared by `reset()`.
    var didComplete: Bool { get }

    /// Reps completed (EMOM timers)
    var completedReps: Int? { get }
    /// Rounds completed (AMRAP timers)
    var completedRounds: Int? { get }

    func reset()
}

// MARK: - Default Implementations

extension WorkoutTimer {
    /// Whether the workout timer has completed (total time has reached zero).
    var isCompleted: Bool {
        totalTimeRemaining <= 0
    }
}
