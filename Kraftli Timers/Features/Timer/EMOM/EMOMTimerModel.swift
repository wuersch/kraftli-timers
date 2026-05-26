//
//  EMOMTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

@Observable
public class EMOMTimerModel: WorkoutTimer {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    @MainActor private(set) var intervalTimeRemaining: TimeInterval
    @MainActor private(set) var isRunning: Bool = false

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

    private var totalStartDate: Date?
    private var pausedTotalTime: TimeInterval?

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
    
    // MARK: - Public Methods
    @MainActor
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        feedbackProvider.onStart()
        startTimer()
    }
    
    @MainActor
    func pause() {
        guard isRunning else { return }

        pausedTotalTime = preciseTotalTimeRemaining  // Keep sub-second precision for smooth resume
        isRunning = false
        timerCoordinator.stop()
    }

    /// Pauses using the authoritative `date` (HealthKit's canonical transition time) rather
    /// than the local clock, so both devices freeze at the identical `remaining`.
    @MainActor
    func pause(at date: Date) {
        guard isRunning, let totalStart = totalStartDate else {
            // No anchor to measure against — fall back to the local-clock freeze.
            pause()
            return
        }

        // Recompute the frozen display from the shared `date` (not the last, possibly-stale tick).
        let elapsed = max(0, date.timeIntervalSince(totalStart))
        setDisplayFields(totalElapsed: elapsed)
        pausedTotalTime = preciseTotalTimeRemaining
        isRunning = false
        timerCoordinator.stop()
    }

    /// Resumes by re-anchoring `totalStartDate` from the shared `date` and the frozen
    /// `remaining`, so both devices adopt the identical absolute anchor. Does not replay
    /// start feedback (remote-driven) and preserves interval/warning state so no sounds repeat.
    @MainActor
    func resume(at date: Date) {
        guard !isRunning else { return }  // Already running → no toggle, no feedback bounce.

        let remaining = pausedTotalTime ?? preciseTotalTimeRemaining
        let anchor = date.addingTimeInterval(-(totalDuration - remaining))
        totalStartDate = timerCoordinator.start(startDate: anchor) { [weak self] in
            self?.update()
        }
        pausedTotalTime = nil
        isRunning = true
    }

    @MainActor
    func reset() {
        timerCoordinator.stop()
        isRunning = false

        totalTimeRemaining = totalDuration
        intervalTimeRemaining = intervalDuration
        preciseTotalTimeRemaining = totalDuration
        preciseIntervalTimeRemaining = intervalDuration

        pausedTotalTime = nil
        lastCompletedInterval = -1
        lastWarningTriggered = false
    }
    
    // MARK: - Private Methods
    @MainActor
    private func startTimer() {
        // Start total timer
        totalStartDate = timerCoordinator.start(
            pausedTime: pausedTotalTime,
            totalDuration: totalDuration
        ) { [weak self] in
            self?.update()
        }

        pausedTotalTime = nil
    }
    
    /// Recomputes the four displayed remaining-time fields from the elapsed time.
    /// Pure display math — no feedback, no interval/warning counter mutation — so it can be
    /// reused by `pause(at:)` to freeze against the canonical date without firing sounds.
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
        guard let totalStart = totalStartDate else {
            return
        }

        let totalElapsed = now().timeIntervalSince(totalStart)

        setDisplayFields(totalElapsed: totalElapsed)

        // Derive interval time from total elapsed (single source of truth)
        if preciseTotalTimeRemaining > 0 {
            // Detect interval transitions (use precise timing). Derive the count from the
            // exact totalDuration rather than the lossy intervalDuration, matching the
            // count properties above (behaviorally identical, just consistent).
            let elapsedIntervalCount = Int(totalElapsed * Double(_totalIntervals) / totalDuration)
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
        } else {
            // Workout complete
            timerCoordinator.stop()
            isRunning = false
            totalTimeRemaining = 0
            intervalTimeRemaining = 0
            preciseTotalTimeRemaining = 0
            preciseIntervalTimeRemaining = 0
            lastWarningTriggered = false
            feedbackProvider.onWorkoutComplete()
        }
    }
}

