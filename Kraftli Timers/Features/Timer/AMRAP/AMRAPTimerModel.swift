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
    let totalDuration: TimeInterval
    private let timerCoordinator: TimerCoordinator
    private let audioFeedbackProvider: AudioFeedbackProvider

    private var startDate: Date?
    private var pausedTime: TimeInterval?

    // MARK: - Computed Properties
    @MainActor
    var progress: Double {
        totalTimeRemaining / totalDuration
    }

    @MainActor
    var elapsedTime: TimeInterval {
        totalDuration - totalTimeRemaining
    }

    // MARK: - WorkoutTimer Protocol
    var completedReps: Int? {
        nil
    }

    @MainActor
    var completedRounds: Int? {
        roundsCompleted
    }

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        timerProvider: TimerProvider,
        feedbackProvider: AudioFeedbackProvider
    ) {
        self.totalDuration = totalDuration
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider)
        self.totalTimeRemaining = totalDuration
        self.audioFeedbackProvider = feedbackProvider
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
        timerCoordinator.stop()
    }

    @MainActor
    func reset() {
        timerCoordinator.stop()
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
        startDate = timerCoordinator.start(
            pausedTime: pausedTime,
            totalDuration: totalDuration
        ) { [weak self] in
            self?.update()
        }

        pausedTime = nil
    }

    @MainActor
    private func update() {
        guard let start = startDate else { return }

        let now = Date()

        let timeElapsed: TimeInterval = now.timeIntervalSince(start)

        totalTimeRemaining = max(0, totalDuration - timeElapsed)

        if totalTimeRemaining <= 0 {
            timerCoordinator.stop()
            isRunning = false
            totalTimeRemaining = 0
            audioFeedbackProvider.playWorkoutComplete()
        }
    }
}
