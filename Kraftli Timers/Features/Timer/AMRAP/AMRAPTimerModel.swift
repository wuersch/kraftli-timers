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
/// `apply(_:)` adopts a state published by the workout's owner; the `start` /
/// `pause` / `resume` methods are local shortcuts that change the state through
/// `TimerStateReducer`, so both paths follow the same rules.
@Observable
class AMRAPTimerModel: WorkoutTimer {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    @MainActor private(set) var isRunning = false
    /// Rounds counted on this device. `apply(_:)` adopts the owner's count; local taps
    /// still increment it directly until the views move to the session controller.
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
    func start() {
        guard !isRunning else { return }

        let date = now()
        if let state, state.isPaused, !state.isFinished(at: date) {
            self.state = reduce(state, .resume, at: date, now: date)
        } else {
            state = makeLocalState(startDate: date)
            didComplete = false
        }
        refresh(at: date)
    }

    @MainActor
    func pause() {
        guard isRunning, let state else { return }

        let date = now()
        self.state = reduce(state, .pause, at: date, now: date)
        refresh(at: date)
    }

    /// Pauses at the supplied `date` instead of the local clock.
    @MainActor
    func pause(at date: Date) {
        guard isRunning, let state else { return }

        // Allow a date slightly ahead of the local clock (it came from another device).
        self.state = reduce(state, .pause, at: date, now: max(now(), date))
        refresh(at: now())
    }

    /// Resumes at the supplied `date` instead of the local clock. Only acts while paused.
    @MainActor
    func resume(at date: Date) {
        guard !isRunning, let state, state.isPaused else { return }

        self.state = reduce(state, .resume, at: date, now: max(now(), date))
        refresh(at: now())
    }

    /// Starts anchored to the supplied absolute `date` (which may lie in the past), so a
    /// late-joining mirror shows the leader's elapsed time instead of starting from zero.
    /// Does not play start feedback (remote-driven start).
    @MainActor
    func start(at date: Date) {
        guard !isRunning else { return }

        state = makeLocalState(startDate: date)
        didComplete = false
        refresh(at: now())
    }

    @MainActor
    func reset() {
        timerCoordinator.stop()
        state = nil
        isRunning = false
        totalTimeRemaining = totalDuration
        roundsCompleted = 0
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

    /// A state for a workout this model runs on its own (no remote owner).
    @MainActor
    private func makeLocalState(startDate: Date) -> TimerState {
        TimerState(
            workoutID: UUID(),
            owner: .current,
            config: TimerConfig(
                timerKindRaw: TimerKind.amrap.rawValue,
                totalDuration: totalDuration,
                intervalCount: nil,
                exerciseName: ""
            ),
            startDate: startDate
        )
    }

    /// Applies one local action through the shared reducer.
    private func reduce(_ state: TimerState, _ action: TimerIntent.Action, at date: Date, now: Date) -> TimerState {
        let intent = TimerIntent(workoutID: state.workoutID, baseRevision: state.revision, action: action, at: date)
        return TimerStateReducer.apply([intent], to: state, now: now)
    }

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
