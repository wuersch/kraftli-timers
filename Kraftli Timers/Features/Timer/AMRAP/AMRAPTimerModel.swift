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
    /// Explicit completion signal — set true only in `update()` when the timer reaches zero while
    /// running, so a `pause(at:)` clamp or stray tick can't trigger the completion path.
    @MainActor private(set) var didComplete = false

    // MARK: - Private Properties
    let totalDuration: TimeInterval
    private let timerCoordinator: TimerCoordinator
    private let feedbackProvider: FeedbackProvider
    /// Wall-clock source. Injectable so tests can drive time deterministically.
    private let now: () -> Date

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
        feedbackProvider: FeedbackProvider,
        now: @escaping () -> Date = { Date() }
    ) {
        self.totalDuration = totalDuration
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider, now: now)
        self.totalTimeRemaining = totalDuration
        self.feedbackProvider = feedbackProvider
        self.now = now
    }

    // MARK: - Public Methods
    @MainActor
    func start() {
        guard !isRunning else { return }

        didComplete = false
        isRunning = true
        startTimer()
    }

    @MainActor
    func pause() {
        guard isRunning else { return }

        pausedTime = totalTimeRemaining
        isRunning = false
        timerCoordinator.stop()
        startDate = nil  // Drop the anchor so a stray enqueued tick can't recompute from it.
    }

    /// Pauses using the authoritative `date` (HealthKit's canonical transition time) rather
    /// than the local clock, so both devices freeze at the identical `remaining`.
    @MainActor
    func pause(at date: Date) {
        guard isRunning, let start = startDate else {
            pause()
            return
        }

        let remaining = max(0, totalDuration - date.timeIntervalSince(start))
        totalTimeRemaining = remaining
        pausedTime = remaining
        isRunning = false
        timerCoordinator.stop()
        startDate = nil  // Drop the anchor so a stray enqueued tick can't recompute from it.
    }

    /// Resumes by re-anchoring `startDate` from the shared `date` and the frozen `remaining`,
    /// so both devices adopt the identical absolute anchor. Only acts while paused.
    @MainActor
    func resume(at date: Date) {
        guard !isRunning else { return }

        let remaining = pausedTime ?? totalTimeRemaining
        let anchor = date.addingTimeInterval(-(totalDuration - remaining))
        startDate = timerCoordinator.start(startDate: anchor) { [weak self] in
            self?.update()
        }
        pausedTime = nil
        isRunning = true
    }

    /// Starts anchored to the supplied absolute `date` (which may lie in the past), so a
    /// late-joining mirror shows the leader's elapsed time instead of starting from zero.
    /// Does not play start feedback (remote-driven start).
    @MainActor
    func start(at date: Date) {
        guard !isRunning else { return }

        didComplete = false
        let elapsed = max(0, now().timeIntervalSince(date))
        totalTimeRemaining = max(0, totalDuration - elapsed)
        startDate = timerCoordinator.start(startDate: date) { [weak self] in
            self?.update()
        }
        pausedTime = nil
        isRunning = true
    }

    @MainActor
    func reset() {
        timerCoordinator.stop()
        isRunning = false
        totalTimeRemaining = totalDuration
        roundsCompleted = 0
        pausedTime = nil
        startDate = nil
        didComplete = false
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
        // Ignore a stray tick enqueued before stop()/pause(): the timer is no longer running, so
        // recomputing from the clock would undo an anchored freeze or fire completion on a paused timer.
        guard isRunning, let start = startDate else { return }

        let timeElapsed: TimeInterval = now().timeIntervalSince(start)

        totalTimeRemaining = max(0, totalDuration - timeElapsed)

        if totalTimeRemaining <= 0 {
            timerCoordinator.stop()
            isRunning = false
            totalTimeRemaining = 0
            didComplete = true
            feedbackProvider.onWorkoutComplete()
        }
    }
}
