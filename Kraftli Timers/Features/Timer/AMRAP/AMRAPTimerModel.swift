//
//  AMRAPTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

/// Renders an AMRAP workout from a `TimerState` (ADR-006).
///
/// All timing comes from the state: the model derives the displayed values from
/// `state.elapsed(at: now())` on every tick and keeps no stopwatch of its own.
/// `apply(_:)` adopts each state the `TimerSessionController` renders — the model
/// never changes the state itself.
@Observable
class AMRAPTimerModel: WorkoutTimer {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    @MainActor private(set) var isRunning = false
    /// Rounds completed, as counted by the workout's owner (`TimerState.roundCount`).
    /// Taps go through `TimerSessionController.incrementRound()`, never to the model.
    @MainActor private(set) var roundsCompleted = 0
    /// Explicit completion signal — set true only when the workout reaches zero (observed on a
    /// tick, or adopted from a completed state), never by a pause or a stop.
    @MainActor private(set) var didComplete = false

    // MARK: - Private Properties
    let totalDuration: TimeInterval
    private let timerCoordinator: TimerCoordinator
    private let feedbackProvider: FeedbackProvider
    /// Wall-clock source. Injectable so tests can drive time deterministically.
    private let now: () -> Date

    /// The timing source of truth. nil until the workout starts (and after `reset()`).
    @MainActor private var state: TimerState?

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

    // MARK: - State-Driven API (ADR-006)

    /// Adopts a state published by the workout's owner and re-renders, including its
    /// round count. No start feedback plays.
    @MainActor
    func apply(_ newState: TimerState) {
        if state?.workoutID != newState.workoutID {
            didComplete = false
        }
        state = newState
        roundsCompleted = newState.roundCount
        refresh(at: now())
    }

    // MARK: - Public Methods
    @MainActor
    func reset() {
        timerCoordinator.stop()
        state = nil
        isRunning = false
        totalTimeRemaining = totalDuration
        roundsCompleted = 0
        didComplete = false
    }

    // MARK: - Private Methods

    /// Re-renders from the state at `date`: remaining time, running flag, ticking and completion.
    @MainActor
    private func refresh(at date: Date) {
        guard let state else { return }
        let wasRunning = isRunning
        totalTimeRemaining = max(0, totalDuration - state.elapsed(at: date))

        let finished = state.isFinished(at: date)
        isRunning = !state.isPaused && !finished

        // Completion: time ran out (a stop is not a completion).
        let completed: Bool = switch state.finish {
        case .completed: true
        case .stopped: false
        case nil: finished
        }
        if completed {
            totalTimeRemaining = 0
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

    @MainActor
    private func update() {
        // Ignore a stray tick enqueued before a pause: the timer is no longer running, so
        // re-rendering would fire completion on a paused timer.
        guard isRunning else { return }
        refresh(at: now())
    }
}
