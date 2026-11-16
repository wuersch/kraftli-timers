//
//  EMOMTimerModel.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

/// Renders an EMOM workout from a `TimerState` (ADR-006): the total and interval time
/// remaining, with a beep per interval. Adopting states, ticking and completion come
/// from `TimerStateRendering`.
@Observable
final class EMOMTimerModel: TimerStateRendering {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    @MainActor private(set) var intervalTimeRemaining: TimeInterval

    // Precise values for smooth progress animations
    @MainActor private var preciseTotalTimeRemaining: TimeInterval
    @MainActor private var preciseIntervalTimeRemaining: TimeInterval

    // MARK: - Private Properties
    private let intervalWarningThreshold: TimeInterval
    private let _totalDuration: TimeInterval
    private let _totalIntervals: Int
    private let intervalDuration: TimeInterval
    private let feedbackProvider: FeedbackProvider
    let core: TimerRenderCore

    // Feedback trackers. Not observed: no view reads them.
    @ObservationIgnored private var lastWarningTriggered = false
    @ObservationIgnored private var lastCompletedInterval: Int = -1

    // MARK: - Computed Properties
    @MainActor
    var overallProgress: Double {
        preciseTotalTimeRemaining / totalDuration
    }

    @MainActor
    var intervalProgress: Double {
        preciseIntervalTimeRemaining / intervalDuration
    }

    @MainActor
    var isIntervalWarning: Bool {
        intervalTimeRemaining <= intervalWarningThreshold
    }

    @MainActor
    var completedIntervals: Int {
        // Scale the elapsed *fraction* by the rep count. The denominator is the exact
        // totalDuration, never the derived (lossy) intervalDuration — so at completion the
        // fraction is exactly 1.0 (x/x) and this lands exactly on the rep count, no epsilon.
        let elapsedFraction = (totalDuration - totalTimeRemaining) / totalDuration
        return min(Int(elapsedFraction * Double(_totalIntervals)), _totalIntervals)
    }

    /// The interval currently in progress (1-based), for display purposes.
    /// Starts at 1 when the workout begins, caps at `totalIntervals` when done.
    @MainActor
    var currentInterval: Int {
        min(completedIntervals + 1, totalIntervals)
    }

    @MainActor
    var totalIntervals: Int {
        _totalIntervals
    }

    // MARK: - WorkoutTimer Protocol
    @MainActor
    var isCompleted: Bool {
        totalTimeRemaining <= 0
    }

    /// A time-boxed workout records its full duration.
    var recordedDuration: TimeInterval {
        totalDuration
    }

    var totalDuration: TimeInterval {
        _totalDuration
    }

    @MainActor
    var completedReps: Int? {
        completedIntervals
    }

    var completedRounds: Int? {
        nil
    }

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        intervalCount: Int = 20,
        intervalWarningThreshold: TimeInterval = 3,
        timerProvider: TimerProvider,
        feedbackProvider: FeedbackProvider,
        now: @escaping () -> Date = { Date() }
    ) {
        precondition(totalDuration > 0, "totalDuration must be > 0")
        precondition(intervalCount > 0, "intervalCount must be > 0")
        precondition(intervalWarningThreshold >= 0, "intervalWarningThreshold must be >= 0")

        // The integer interval count is the source of truth; intervalDuration is derived
        // from it exactly once here so we never decode the count back out of a float.
        let intervalDuration = totalDuration / Double(intervalCount)

        self._totalDuration = totalDuration
        self._totalIntervals = intervalCount
        self.intervalDuration = intervalDuration
        self.intervalWarningThreshold = intervalWarningThreshold
        self.feedbackProvider = feedbackProvider
        self.core = TimerRenderCore(timerProvider: timerProvider, feedbackProvider: feedbackProvider, now: now)
        self.totalTimeRemaining = totalDuration
        self.intervalTimeRemaining = intervalDuration
        self.preciseTotalTimeRemaining = totalDuration
        self.preciseIntervalTimeRemaining = intervalDuration
    }

    // Convenience initializer: Rep-based (Busy Dad Style)
    convenience init(
        totalReps: Int,
        totalMinutes: Int,
        timerProvider: TimerProvider,
        feedbackProvider: FeedbackProvider
    ) {
        precondition(totalReps > 0, "totalReps must be > 0")
        precondition(totalMinutes > 0, "totalMinutes must be > 0")

        let totalSeconds = TimeInterval(totalMinutes * 60)

        self.init(
            totalDuration: totalSeconds,
            intervalCount: totalReps,
            timerProvider: timerProvider,
            feedbackProvider: feedbackProvider
        )
    }

    // MARK: - TimerStateRendering

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
            seedTrackers(elapsed: newState.elapsed(at: date))
        }
    }

    /// Recomputes the four displayed remaining-time fields from the elapsed time.
    /// Pure display math — no feedback, no interval/warning counter mutation.
    @MainActor
    func render(elapsed totalElapsed: TimeInterval) {
        // Calculate precise values for smooth progress animations
        preciseTotalTimeRemaining = max(0, totalDuration - totalElapsed)
        let preciseIntervalElapsed = totalElapsed.truncatingRemainder(dividingBy: intervalDuration)
        preciseIntervalTimeRemaining = intervalDuration - preciseIntervalElapsed

        // Floor to whole seconds for synchronized display
        let totalElapsedSeconds = floor(totalElapsed)
        totalTimeRemaining = max(0, totalDuration - totalElapsedSeconds)
        let intervalElapsedSeconds = totalElapsedSeconds.truncatingRemainder(dividingBy: intervalDuration)
        intervalTimeRemaining = intervalDuration - intervalElapsedSeconds
    }

    /// Plays the interval beep and the warning as the clock passes them.
    @MainActor
    func didTick(elapsed: TimeInterval) {
        guard elapsed > 0 else { return }

        // Detect interval transitions (use precise timing). Derive the count from the
        // exact totalDuration rather than the lossy intervalDuration, matching the
        // count properties above (behaviorally identical, just consistent).
        let elapsedIntervalCount = Int(elapsed * Double(_totalIntervals) / totalDuration)
        if elapsedIntervalCount > lastCompletedInterval {
            lastCompletedInterval = elapsedIntervalCount
            lastWarningTriggered = false
            if elapsedIntervalCount > 0 {
                feedbackProvider.onIntervalComplete()
            }
        }

        // Warning sound at threshold (use precise timing)
        if preciseIntervalTimeRemaining <= intervalWarningThreshold && !lastWarningTriggered {
            feedbackProvider.onWarning()
            lastWarningTriggered = true
        }
    }

    @MainActor
    func renderCompletion() {
        intervalTimeRemaining = 0
        preciseIntervalTimeRemaining = 0
        lastWarningTriggered = false
    }

    @MainActor
    func resetDisplay() {
        totalTimeRemaining = totalDuration
        intervalTimeRemaining = intervalDuration
        preciseTotalTimeRemaining = totalDuration
        preciseIntervalTimeRemaining = intervalDuration

        lastCompletedInterval = -1
        lastWarningTriggered = false
    }

    // MARK: - Private Methods

    /// Sets the interval/warning trackers as if they had followed the workout up to `elapsed`.
    @MainActor
    private func seedTrackers(elapsed: TimeInterval) {
        lastCompletedInterval = Int(elapsed * Double(_totalIntervals) / totalDuration)
        let intervalElapsed = elapsed.truncatingRemainder(dividingBy: intervalDuration)
        lastWarningTriggered = (intervalDuration - intervalElapsed) <= intervalWarningThreshold
    }
}
