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
        let elapsedTime = totalDuration - totalTimeRemaining
        // +epsilon so an exact boundary (e.g. 113.9999… from the derived float) snaps up;
        // clamp so completion reports the authoritative total, never one short.
        return min(Int(elapsedTime / intervalDuration + 1e-6), _totalIntervals)
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
        feedbackProvider: FeedbackProvider
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
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider)
        self.feedbackProvider = feedbackProvider
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
    
    @MainActor
    private func update() {
        guard let totalStart = totalStartDate else {
            return
        }

        let now = Date()
        let totalElapsed = now.timeIntervalSince(totalStart)

        // Calculate precise values for smooth progress animations
        preciseTotalTimeRemaining = max(0, totalDuration - totalElapsed)
        let preciseIntervalElapsed = totalElapsed.truncatingRemainder(dividingBy: intervalDuration)
        preciseIntervalTimeRemaining = intervalDuration - preciseIntervalElapsed

        // Floor to whole seconds for synchronized display
        let totalElapsedSeconds = floor(totalElapsed)
        totalTimeRemaining = max(0, totalDuration - totalElapsedSeconds)
        let intervalElapsedSeconds = totalElapsedSeconds.truncatingRemainder(dividingBy: intervalDuration)
        intervalTimeRemaining = intervalDuration - intervalElapsedSeconds

        // Derive interval time from total elapsed (single source of truth)
        if preciseTotalTimeRemaining > 0 {
            // Detect interval transitions (use precise timing)
            let elapsedIntervalCount = Int(totalElapsed / intervalDuration)
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

