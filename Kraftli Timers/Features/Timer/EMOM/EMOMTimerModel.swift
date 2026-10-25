//
//  EMOMTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

/// Renders an EMOM workout from a `TimerState` (ADR-006).
///
/// All timing comes from the state: the model derives the displayed values from
/// `state.elapsed(at: now())` on every tick and keeps no stopwatch of its own.
/// `apply(_:)` adopts each state the `TimerSessionController` renders — the model
/// never changes the state itself.
@Observable
public class EMOMTimerModel: WorkoutTimer {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    @MainActor private(set) var intervalTimeRemaining: TimeInterval
    @MainActor private(set) var isRunning: Bool = false
    /// Explicit completion signal — set true only when the workout reaches zero (observed on a
    /// tick, or adopted from a completed state), never by a pause or a stop.
    @MainActor private(set) var didComplete = false

    // Precise values for smooth progress animations
    @MainActor private var preciseTotalTimeRemaining: TimeInterval
    @MainActor private var preciseIntervalTimeRemaining: TimeInterval

    // MARK: - Private Properties
    private let intervalWarningThreshold: TimeInterval
    private let _totalDuration: TimeInterval
    private let _totalIntervals: Int
    private let intervalDuration: TimeInterval
    private let timerCoordinator: TimerCoordinator
    private let feedbackProvider: FeedbackProvider
    /// Wall-clock source. Injectable so tests can drive time deterministically.
    private let now: () -> Date

    /// The timing source of truth. nil until the workout starts (and after `reset()`).
    @MainActor private var state: TimerState?

    private var lastWarningTriggered = false
    private var lastCompletedInterval: Int = -1

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
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider, now: now)
        self.feedbackProvider = feedbackProvider
        self.now = now
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

    // MARK: - State-Driven API (ADR-006)

    /// Adopts a state published by the workout's owner and re-renders.
    ///
    /// A state that continues the current one (same workout, same elapsed time — e.g. a
    /// pause or resume) keeps the interval/warning trackers. A state that jumps (another
    /// workout, a late join, a conflict rollback) re-seeds them from the new elapsed time,
    /// so feedback for already-passed intervals is never replayed. No start feedback plays.
    @MainActor
    func apply(_ newState: TimerState) {
        let date = now()
        let jumped = state.map {
            $0.workoutID != newState.workoutID
                || abs($0.elapsed(at: date) - newState.elapsed(at: date)) > 0.5
        } ?? true
        if state?.workoutID != newState.workoutID {
            didComplete = false
        }
        state = newState
        if jumped {
            seedTrackers(elapsed: newState.elapsed(at: date))
        }
        refresh(at: date, playsFeedback: false)
    }

    // MARK: - Public Methods
    @MainActor
    func reset() {
        timerCoordinator.stop()
        state = nil
        isRunning = false

        totalTimeRemaining = totalDuration
        intervalTimeRemaining = intervalDuration
        preciseTotalTimeRemaining = totalDuration
        preciseIntervalTimeRemaining = intervalDuration

        didComplete = false
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

    /// Re-renders from the state at `date`: display fields, running flag, ticking,
    /// interval/warning feedback (on ticks only) and completion.
    @MainActor
    private func refresh(at date: Date, playsFeedback: Bool) {
        guard let state else { return }
        let wasRunning = isRunning
        let elapsed = state.elapsed(at: date)
        setDisplayFields(totalElapsed: elapsed)

        let finished = state.isFinished(at: date)
        isRunning = !state.isPaused && !finished

        if playsFeedback && isRunning && elapsed > 0 {
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

        // Completion: time ran out (a stop is not a completion).
        let completed: Bool = switch state.finish {
        case .completed: true
        case .stopped: false
        case nil: finished
        }
        if completed {
            intervalTimeRemaining = 0
            preciseIntervalTimeRemaining = 0
            lastWarningTriggered = false
            if !didComplete {
                didComplete = true
                if wasRunning {
                    feedbackProvider.onWorkoutComplete()
                }
            }
        }

        if isRunning, !timerCoordinator.isActive {
            timerCoordinator.start(startDate: state.startDate) { [weak self] in
                self?.update()
            }
        } else if !isRunning {
            timerCoordinator.stop()
        }
    }

    /// Recomputes the four displayed remaining-time fields from the elapsed time.
    /// Pure display math — no feedback, no interval/warning counter mutation.
    @MainActor
    private func setDisplayFields(totalElapsed: TimeInterval) {
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

    @MainActor
    private func update() {
        // Ignore a stray tick enqueued before a pause: the timer is no longer running, so
        // re-rendering would fire interval/warning/completion on a paused timer.
        guard isRunning else { return }
        refresh(at: now(), playsFeedback: true)
    }
}
