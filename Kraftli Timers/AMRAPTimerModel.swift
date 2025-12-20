//
//  AMRAPTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

@Observable
class AMRAPTimerModel: WorkoutTimer {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    @MainActor private(set) var isRunning = false
    @MainActor private(set) var roundsCompleted = 0

    // MARK: - Private Properties
    private let totalDuration: TimeInterval
    private let timerProvider: TimerProvider

    private var timer: Any?
    private var startDate: Date?
    private var pausedTime: TimeInterval?

    // MARK: - Computed Properties
    @MainActor
    var progress: Double {
        1.0 - (totalTimeRemaining / totalDuration)
    }

    @MainActor
    var elapsedTime: TimeInterval {
        totalDuration - totalTimeRemaining
    }

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        timerProvider: TimerProvider = DisplayLinkTimerProvider()
    ) {
        self.totalDuration = totalDuration
        self.timerProvider = timerProvider
        self.totalTimeRemaining = totalDuration
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

        pausedTime = totalTimeRemaining
        isRunning = false
        stopTimer()
    }

    @MainActor
    func reset() {
        stopTimer()
        isRunning = false
        totalTimeRemaining = totalDuration
        roundsCompleted = 0
        pausedTime = nil
    }

    @MainActor
    func incrementRoundsCompleted() {
        roundsCompleted += 1
    }

    @MainActor
    func decrementRoundsCompleted() {
        guard roundsCompleted > 0 else { return }
        roundsCompleted -= 1
    }

    // MARK: - Private Methods
    @MainActor
    private func startTimer() {
        let now = Date()

        if let pausedTime = pausedTime {
            startDate = now.addingTimeInterval(-totalDuration + pausedTime)
        } else {
            startDate = now
        }

        pausedTime = nil

        timer = timerProvider.scheduleTimer(interval: 0.2, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.update()
            }
        }
    }

    @MainActor
    private func update() {
        guard let start = startDate else { return }

        let now = Date()

        let timeElapsed: TimeInterval = now.timeIntervalSince(start)

        totalTimeRemaining = max(0, totalDuration - timeElapsed)

        if totalTimeRemaining <= 0 {
            stopTimer()
            isRunning = false
            totalTimeRemaining = 0
        }
    }

    private func stopTimer() {
        if let timer = timer {
            timerProvider.invalidateTimer(timer)
            self.timer = nil
        }
        startDate = nil
    }

    deinit {
        stopTimer()
    }
}
