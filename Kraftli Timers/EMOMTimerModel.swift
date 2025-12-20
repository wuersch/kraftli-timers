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
    private let intervalWarningThreshold: TimeInterval = 5
    private let totalDuration: TimeInterval
    private let intervalDuration: TimeInterval
    private let timerProvider: TimerProvider
    
    private var timer: Any?
    private var totalStartDate: Date?
    private var intervalStartDate: Date?
    private var pausedTotalTime: TimeInterval?
    private var pausedIntervalTime: TimeInterval?
    
    // MARK: - Computed Properties
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
        timerProvider: TimerProvider = DisplayLinkTimerProvider()
    ) {
        self.totalDuration = totalDuration
        self.intervalDuration = intervalDuration
        self.timerProvider = timerProvider
        self.totalTimeRemaining = totalDuration
        self.intervalTimeRemaining = intervalDuration
    }
    
    // Convenience initializer: Rep-based (Busy Dad Style)
    convenience init(
        totalReps: Int,
        totalMinutes: Int,
        timerProvider: TimerProvider = DisplayLinkTimerProvider()
    ) {
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
        startTimer()
    }
    
    @MainActor
    func pause() {
        guard isRunning else { return }
        
        pausedTotalTime = totalTimeRemaining
        pausedIntervalTime = intervalTimeRemaining
        isRunning = false
        stopTimer()
    }
    
    @MainActor
    func reset() {
        stopTimer()
        isRunning = false
        
        totalTimeRemaining = totalDuration
        intervalTimeRemaining = intervalDuration
        
        pausedTotalTime = nil
        pausedIntervalTime = nil
    }
    
    // MARK: - Private Methods
    @MainActor
    private func startTimer() {
        let now = Date()
        
        if let pausedTotal = pausedTotalTime {
            totalStartDate = now.addingTimeInterval(-totalDuration + pausedTotal)
        } else {
            totalStartDate = now
        }
        
        if let pausedInterval = pausedIntervalTime {
            intervalStartDate = now.addingTimeInterval(-intervalDuration + pausedInterval)
        } else {
            intervalStartDate = now
        }
        
        pausedTotalTime = nil
        pausedIntervalTime = nil
        
        timer = timerProvider.scheduleTimer(interval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.update()
            }
        }
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
        
        if(intervalTimeRemaining <= 0 && totalTimeRemaining > 0) {
            intervalStartDate = now
            intervalTimeRemaining = intervalDuration
        }
        
        if totalTimeRemaining <= 0 {
            stopTimer()
            isRunning = false
            totalTimeRemaining = 0
            intervalTimeRemaining = 0
        }
    }
    
    private func stopTimer() {
        if let timer = timer {
            timerProvider.invalidateTimer(timer)
            self.timer = nil
        }
        totalStartDate = nil
        intervalStartDate = nil
    }
    
    deinit {
        stopTimer()
    }
}

