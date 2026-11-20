//
//  EMOMTimerModel.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

/// Renders an EMOM workout from a `TimerState` (ADR-006): the total and interval time
/// remaining, with a beep per interval. Adopting states, ticking and completion come
/// from `TimerModel`.
@Observable
final class EMOMTimerModel: TimerModel {
    let totalDuration: TimeInterval
    /// The integer interval count is the source of truth; `intervalDuration` is derived
    /// from it once, so the count is never decoded back out of a float.
    let totalIntervals: Int
    let intervalDuration: TimeInterval
    private let intervalWarningThreshold: TimeInterval
    private let feedbackProvider: FeedbackProvider
    let core: TimerRenderCore

    // Feedback trackers. Not observed: no view reads them.
    @ObservationIgnored private var lastWarningTriggered = false
    @ObservationIgnored private var lastCompletedInterval = -1

    // MARK: - Displayed Values (derived from the core)
    //
    // The times shown are floored to whole seconds, so the total and the interval tick
    // over together. The progress rings use the precise time, for smooth animation.

    @MainActor
    var totalTimeRemaining: TimeInterval {
        max(0, totalDuration - floor(core.elapsed))
    }

    /// Pinned to 0 once the workout has completed.
    @MainActor
    var intervalTimeRemaining: TimeInterval {
        isCompleted ? 0 : intervalRemaining(at: floor(core.elapsed))
    }

    @MainActor
    var overallProgress: Double {
        max(0, totalDuration - core.elapsed) / totalDuration
    }

    @MainActor
    var intervalProgress: Double {
        isCompleted ? 0 : intervalRemaining(at: core.elapsed) / intervalDuration
    }

    @MainActor
    var isIntervalWarning: Bool {
        intervalTimeRemaining <= intervalWarningThreshold
    }

    @MainActor
    var completedIntervals: Int {
        intervalsPassed(at: floor(core.elapsed))
    }

    /// The interval currently in progress (1-based), for display purposes.
    /// Starts at 1 when the workout begins, caps at `totalIntervals` when done.
    @MainActor
    var currentInterval: Int {
        min(completedIntervals + 1, totalIntervals)
    }

    /// A time-boxed workout records its full duration, and a rep per interval done.
    @MainActor
    var result: WorkoutResult {
        WorkoutResult(duration: totalDuration, reps: completedIntervals)
    }

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval,
        intervalCount: Int,
        intervalWarningThreshold: TimeInterval = 3,
        timerProvider: TimerProvider,
        feedbackProvider: FeedbackProvider,
        now: @escaping () -> Date = { Date() }
    ) {
        precondition(totalDuration > 0, "totalDuration must be > 0")
        precondition(intervalCount > 0, "intervalCount must be > 0")
        precondition(intervalWarningThreshold >= 0, "intervalWarningThreshold must be >= 0")

        self.totalDuration = totalDuration
        self.totalIntervals = intervalCount
        self.intervalDuration = totalDuration / Double(intervalCount)
        self.intervalWarningThreshold = intervalWarningThreshold
        self.feedbackProvider = feedbackProvider
        self.core = TimerRenderCore(timerProvider: timerProvider, feedbackProvider: feedbackProvider, now: now)
    }

    // MARK: - TimerModel

    /// A state that continues the current one (same workout, same elapsed time — e.g. a
    /// pause or resume) keeps the interval/warning trackers. A state that jumps (another
    /// workout, a late join, a conflict rollback) re-seeds them from the new elapsed time,
    /// so feedback for already-passed intervals is never replayed.
    @MainActor
    func didAdopt(_ newState: TimerState, replacing previous: TimerState?, at date: Date) {
        let jumped = previous.map {
            $0.workoutID != newState.workoutID
                || abs($0.elapsed(at: date) - newState.elapsed(at: date)) > 0.5
        } ?? true
        if jumped {
            let elapsed = newState.elapsed(at: date)
            lastCompletedInterval = intervalsPassed(at: elapsed)
            lastWarningTriggered = intervalRemaining(at: elapsed) <= intervalWarningThreshold
        }
    }

    /// Plays the interval beep and the warning as the clock passes them.
    @MainActor
    func didTick(elapsed: TimeInterval) {
        guard elapsed > 0 else { return }

        let passed = intervalsPassed(at: elapsed)
        if passed > lastCompletedInterval {
            lastCompletedInterval = passed
            lastWarningTriggered = false
            if passed > 0 {
                feedbackProvider.onIntervalComplete()
            }
        }

        if !lastWarningTriggered, intervalRemaining(at: elapsed) <= intervalWarningThreshold {
            feedbackProvider.onWarning()
            lastWarningTriggered = true
        }
    }

    // MARK: - Interval Math

    /// Intervals fully passed at `elapsed`. Scales the elapsed *fraction* by the count,
    /// with the exact `totalDuration` (never the derived, lossy `intervalDuration`) as the
    /// denominator: at the end the fraction is exactly 1.0, so this lands exactly on the
    /// count, no epsilon.
    private func intervalsPassed(at elapsed: TimeInterval) -> Int {
        min(Int(elapsed / totalDuration * Double(totalIntervals)), totalIntervals)
    }

    /// Time left in the interval running at `elapsed`.
    private func intervalRemaining(at elapsed: TimeInterval) -> TimeInterval {
        intervalDuration - elapsed.truncatingRemainder(dividingBy: intervalDuration)
    }
}
