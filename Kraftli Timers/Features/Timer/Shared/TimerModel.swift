//
//  TimerModel.swift
//  Kraftli Timers
//
//  What the three timer models (EMOM, AMRAP, For Time) have in common: adopting a
//  `TimerState`, ticking while it runs, and detecting completion (ADR-006).
//  Shared by the iPhone and Watch targets.
//
//  ## Why a protocol extension plus a core object
//  The shared *behavior* lives in the `TimerModel` extension, the shared
//  *stored state* in `TimerRenderCore`: protocol extensions can't add stored properties,
//  and `@Observable` doesn't mix well with class inheritance. Each model owns a core
//  (composition) and supplies only what differs per kind through the protocol's hooks.
//

import Foundation

// MARK: - Core

/// The stored state every timer model needs to render a `TimerState`.
///
/// `@Observable`, so a view reading `model.isRunning` (which forwards here) is updated
/// when the core's value changes: observation tracks the property that is actually read,
/// no matter which object it lives on.
@Observable
@MainActor
final class TimerRenderCore {
    fileprivate(set) var isRunning = false
    fileprivate(set) var didComplete = false

    /// Workout time elapsed, pauses excluded, as of the last adopted state or tick. The
    /// models derive every displayed value from it, so they store no display state.
    fileprivate(set) var elapsed: TimeInterval = 0

    /// Rounds counted by the workout's owner (`TimerState.roundCount`; AMRAP).
    fileprivate(set) var roundCount = 0

    /// The timing source of truth. nil until the workout starts (and after `reset()`).
    @ObservationIgnored fileprivate(set) var state: TimerState?

    @ObservationIgnored private let timerCoordinator: TimerCoordinator
    @ObservationIgnored fileprivate let feedbackProvider: FeedbackProvider
    /// Wall-clock source. Injectable so tests can drive time deterministically.
    @ObservationIgnored fileprivate let now: () -> Date

    init(
        timerProvider: TimerProvider,
        feedbackProvider: FeedbackProvider,
        now: @escaping () -> Date
    ) {
        self.timerCoordinator = TimerCoordinator(timerProvider: timerProvider)
        self.feedbackProvider = feedbackProvider
        self.now = now
    }

    /// Ticks while the workout runs, and stops otherwise.
    fileprivate func setTicking(_ onTick: @escaping () -> Void) {
        if isRunning, !timerCoordinator.isActive {
            timerCoordinator.start(updateBlock: onTick)
        } else if !isRunning {
            timerCoordinator.stop()
        }
    }

    fileprivate func stopTicking() {
        timerCoordinator.stop()
    }
}

// MARK: - Protocol

/// A timer model: renders a `TimerState` for the timer views (ADR-006).
///
/// All timing comes from the state: on every adopted state and tick the core stores
/// `state.elapsed(at: now())`, and the model derives its displayed values from
/// `core.elapsed` as computed properties. It keeps no stopwatch and no display state of
/// its own. `apply(_:)` adopts each state the `TimerSessionController` renders; the model
/// never changes the state itself.
///
/// Starting, pausing and resuming go through `TimerSessionController`, never to the
/// model. A conforming model provides its `core`, its `result` and, if it needs them, the
/// hooks below. `apply(_:)`, `reset()`, `isRunning` and `isCompleted` come from the
/// extension.
protocol TimerModel: AnyObject {
    var core: TimerRenderCore { get }

    /// What the workout achieved so far; recorded when it completes.
    var result: WorkoutResult { get }

    /// Called when a new state is adopted, before it is rendered (e.g. to re-seed
    /// feedback trackers after a jump).
    func didAdopt(_ newState: TimerState, replacing previous: TimerState?, at date: Date)

    /// Called on a tick while the workout runs, for feedback tied to the clock (e.g.
    /// interval beeps). Never called for an adopted state, so joining or resyncing a
    /// workout replays nothing.
    func didTick(elapsed: TimeInterval)
}

extension TimerModel {
    func didAdopt(_ newState: TimerState, replacing previous: TimerState?, at date: Date) {}
    func didTick(elapsed: TimeInterval) {}
}

// MARK: - Shared behavior

extension TimerModel {
    var isRunning: Bool {
        core.isRunning
    }

    /// True once the workout reached zero or was declared done (observed on a tick, or
    /// adopted from a completed state), never for a pause or a stop. Cleared by `reset()`
    /// and by adopting another workout. Completion observers key off this.
    var isCompleted: Bool {
        core.didComplete
    }

    /// Signals a count of the pre-workout countdown through the model's feedback, so the
    /// countdown is silent whenever the workout's other signals are (UC-0010 Sound off).
    func countdownDidCount() {
        core.feedbackProvider.onCountdownCount()
    }

    /// Adopts a state published by the workout's owner and re-renders. No feedback plays
    /// for what already happened in it.
    func apply(_ newState: TimerState) {
        let date = core.now()
        let previous = core.state
        if previous?.workoutID != newState.workoutID {
            core.didComplete = false
        }
        core.state = newState
        core.roundCount = newState.roundCount
        didAdopt(newState, replacing: previous, at: date)
        refresh(at: date, isTick: false)
    }

    func reset() {
        core.stopTicking()
        core.state = nil
        core.isRunning = false
        core.didComplete = false
        core.elapsed = 0
        core.roundCount = 0
    }

    /// Re-renders from the state at `date`: elapsed time, running flag, completion and
    /// ticking.
    private func refresh(at date: Date, isTick: Bool) {
        guard let state = core.state else { return }
        let wasRunning = core.isRunning
        let elapsed = state.elapsed(at: date)
        core.elapsed = elapsed

        let finished = state.isFinished(at: date)
        core.isRunning = !state.isPaused && !finished

        if isTick, core.isRunning {
            didTick(elapsed: elapsed)
        }

        // Completion: the time ran out or the workout was declared done. A stop is not a
        // completion. An open-ended workout never runs out, so only `.completed` ends it.
        let completed: Bool = switch state.finish {
        case .completed: true
        case .stopped: false
        case nil: finished
        }
        if completed, !core.didComplete {
            core.didComplete = true
            if wasRunning {
                core.feedbackProvider.onWorkoutComplete()
            }
        }

        core.setTicking { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        // Ignore a stray tick enqueued before a pause or finish: the timer is no longer
        // running, so re-rendering would fire feedback or completion on a stopped timer.
        guard core.isRunning else { return }
        refresh(at: core.now(), isTick: true)
    }
}
