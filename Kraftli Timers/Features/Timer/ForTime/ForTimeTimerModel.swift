//
//  ForTimeTimerModel.swift
//  Kraftli Timers
//
//  Renders a For Time workout: a stopwatch that counts up until declared done.
//

import Foundation

/// Renders a For Time workout from a `TimerState` (ADR-006, ADR-0010).
///
/// The workout is open-ended: the state has no duration, and only a `done` intent —
/// sent through `TimerSessionController.done()` — completes it. Like the other models,
/// this one keeps no stopwatch of its own; it derives the elapsed time from
/// `state.elapsed(at: now())` on every tick. It gives no signals during the workout.
@Observable
class ForTimeTimerModel: WorkoutTimer {
    // MARK: - Published Properties (MainActor isolated)
    /// Active time so far, pauses excluded; frozen while paused and once finished.
    @MainActor private(set) var elapsedTime: TimeInterval = 0
    @MainActor private(set) var isRunning = false
    /// Explicit completion signal — set true only when the workout was declared done,
    /// never by a pause or a stop.
    @MainActor private(set) var didComplete = false

    // MARK: - Private Properties
    let targetReps: Int
    private let timerCoordinator: TimerCoordinator
    private let feedbackProvider: FeedbackProvider
    /// Wall-clock source. Injectable so tests can drive time deterministically.
    private let now: () -> Date

    /// The timing source of truth. nil until the workout starts (and after `reset()`).
    @MainActor private var state: TimerState?

    // MARK: - Computed Properties

    /// Position within the current minute (0..<1), for the arc that circles once per minute.
    @MainActor
    var minuteProgress: Double {
        elapsedTime.truncatingRemainder(dividingBy: 60) / 60
    }

    /// The finish time to the second: whole seconds, at least 1 so a log is never empty.
    @MainActor
    var finishTime: TimeInterval {
        max(1, elapsedTime.rounded(.down))
    }

    /// Seconds per rep at the finish time.
    @MainActor
    var pace: TimeInterval {
        finishTime / Double(targetReps)
    }

    // MARK: - WorkoutTimer Protocol
    @MainActor
    var isCompleted: Bool {
        didComplete
    }

    @MainActor
    var recordedDuration: TimeInterval {
        finishTime
    }

    var completedReps: Int? {
        targetReps
    }

    var completedRounds: Int? {
        nil
    }

    // MARK: - Initialization
    init(
        targetReps: Int = 100,
        timerProvider: TimerProvider,
        feedbackProvider: FeedbackProvider,
        now: @escaping () -> Date = { Date() }
    ) {
        precondition(targetReps > 0, "targetReps must be > 0")
        self.targetReps = targetReps
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider, now: now)
        self.feedbackProvider = feedbackProvider
        self.now = now
    }

    // MARK: - State-Driven API (ADR-006)

    /// Adopts a state published by the workout's owner and re-renders. No start feedback plays.
    @MainActor
    func apply(_ newState: TimerState) {
        if state?.workoutID != newState.workoutID {
            didComplete = false
        }
        state = newState
        refresh(at: now())
    }

    // MARK: - Public Methods
    @MainActor
    func reset() {
        timerCoordinator.stop()
        state = nil
        isRunning = false
        elapsedTime = 0
        didComplete = false
    }

    // MARK: - Private Methods

    /// Re-renders from the state at `date`: elapsed time, running flag, ticking and completion.
    @MainActor
    private func refresh(at date: Date) {
        guard let state else { return }
        let wasRunning = isRunning
        elapsedTime = state.elapsed(at: date)
        isRunning = !state.isPaused && !state.isFinished(at: date)

        // Only a declared done completes an open-ended workout; a stop never does.
        if case .completed = state.finish, !didComplete {
            didComplete = true
            if wasRunning {
                feedbackProvider.onWorkoutComplete()
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

    @MainActor
    private func update() {
        // Ignore a stray tick enqueued before a pause or finish.
        guard isRunning else { return }
        refresh(at: now())
    }
}
