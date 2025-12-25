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
    
    // MARK: - Private Properties
    private let intervalWarningThreshold: TimeInterval
    private let totalDuration: TimeInterval
    private let intervalDuration: TimeInterval
    private let timerCoordinator: TimerCoordinator
    private let feedbackProvider: FeedbackProvider

    private var totalStartDate: Date?
    private var intervalStartDate: Date?
    private var pausedTotalTime: TimeInterval?
    private var pausedIntervalTime: TimeInterval?

    private var lastWarningTriggered = false
    
    // MARK: - Computed Properties
    @MainActor
    var overallProgress: Double {
        totalTimeRemaining / totalDuration
    }
    
    @MainActor
    var intervalProgress: Double {
        intervalTimeRemaining / intervalDuration
    }
    
    @MainActor
    var isIntervalWarning: Bool {
        intervalTimeRemaining <= intervalWarningThreshold
    }
    
    @MainActor
    var completedIntervals: Int {
        let elapsedTime = totalDuration - totalTimeRemaining
        return Int(elapsedTime / intervalDuration)
    }
    
    @MainActor
    var totalIntervals: Int {
        Int(totalDuration / intervalDuration)
    }
    
    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        intervalDuration: TimeInterval = 60,
        intervalWarningThreshold: TimeInterval = 3,
        timerProvider: TimerProvider = DisplayLinkTimerProvider(),
        feedbackProvider: FeedbackProvider = AudioFeedbackProvider()
    ) {
        precondition(totalDuration > 0, "totalDuration must be > 0")
        precondition(intervalDuration > 0, "intervalDuration must be > 0")
        precondition(totalDuration >= intervalDuration, "totalDuration must be >= intervalDuration")
        precondition(intervalWarningThreshold >= 0, "intervalWarningThreshold must be >= 0")

        self.totalDuration = totalDuration
        self.intervalDuration = intervalDuration
        self.intervalWarningThreshold = intervalWarningThreshold
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider)
        self.feedbackProvider = feedbackProvider
        self.totalTimeRemaining = totalDuration
        self.intervalTimeRemaining = intervalDuration
    }
    
    // Convenience initializer: Rep-based (Busy Dad Style)
    convenience init(
        totalReps: Int,
        totalMinutes: Int,
        timerProvider: TimerProvider = DisplayLinkTimerProvider(),
        feedbackProvider: FeedbackProvider = AudioFeedbackProvider()
    ) {
        precondition(totalReps > 0, "totalReps must be > 0")
        precondition(totalMinutes > 0, "totalMinutes must be > 0")
        
        let totalSeconds = totalMinutes * 60
        let intervalSeconds = totalSeconds / totalReps
        
        self.init(
            totalDuration: TimeInterval(totalSeconds),
            intervalDuration: TimeInterval(intervalSeconds),
            timerProvider: timerProvider
        )
    }
    
    // MARK: - Public Methods
    @MainActor
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        feedbackProvider.playStart()
        startTimer()
    }
    
    @MainActor
    func pause() {
        guard isRunning else { return }

        pausedTotalTime = totalTimeRemaining
        pausedIntervalTime = intervalTimeRemaining
        isRunning = false
        timerCoordinator.stop()
    }
    
    @MainActor
    func reset() {
        timerCoordinator.stop()
        isRunning = false

        totalTimeRemaining = totalDuration
        intervalTimeRemaining = intervalDuration

        pausedTotalTime = nil
        pausedIntervalTime = nil
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

        // Calculate interval start date
        let now = Date()
        if let pausedInterval = pausedIntervalTime {
            intervalStartDate = now.addingTimeInterval(-intervalDuration + pausedInterval)
        } else {
            intervalStartDate = now
        }

        pausedTotalTime = nil
        pausedIntervalTime = nil
    }
    
    @MainActor
    private func update() {
        guard let totalStart = totalStartDate,
              let intervalStart = intervalStartDate else {
            return
        }
        
        let now = Date()
        let totalElapsed = now.timeIntervalSince(totalStart)
        let intervalElapsed = now.timeIntervalSince(intervalStart)
        
        totalTimeRemaining = max(0, totalDuration - totalElapsed)
        intervalTimeRemaining = max(0, intervalDuration - intervalElapsed)
        
        // Warning sound at (intervalWarningThreshold) seconds
        if intervalTimeRemaining <= intervalWarningThreshold && intervalTimeRemaining > 0 && !lastWarningTriggered {
            feedbackProvider.playWarning()
            lastWarningTriggered = true
        }
        
        if(intervalTimeRemaining <= 0 && totalTimeRemaining > 0) {
            intervalStartDate = now
            intervalTimeRemaining = intervalDuration
            lastWarningTriggered = false
            feedbackProvider.playIntervalComplete()
        }
        
        if totalTimeRemaining <= 0 {
            timerCoordinator.stop()
            isRunning = false
            totalTimeRemaining = 0
            intervalTimeRemaining = 0
            lastWarningTriggered = false
            feedbackProvider.playWorkoutComplete()
        }
    }
}

