//
//  TimerStateRendering.swift
//  Kraftli Timers
//
//  What the three timer models (EMOM, AMRAP, For Time) have in common: adopting a
//  `TimerState`, ticking while it runs, and detecting completion (ADR-006).
//  Shared by the iPhone and Watch targets.
//
//  ## Why a protocol extension plus a core object
//  The shared *behavior* lives in the `TimerStateRendering` extension, the shared
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

/// A timer model that renders a `TimerState`.
///
/// All timing comes from the state: the model derives the displayed values from
/// `state.elapsed(at: now())` on every tick and keeps no stopwatch of its own. `apply(_:)`
/// adopts each state the `TimerSessionController` renders; the model never changes the
/// state itself.
///
/// A conforming model provides its `core` and the display hooks below. `apply(_:)`,
/// `reset()`, `isRunning` and `didComplete` come from the extension.
protocol TimerStateRendering: WorkoutTimer {
    var core: TimerRenderCore { get }

    /// Updates the displayed values for the workout time `elapsed`. Called on every
    /// adopted state and every tick.
    func render(elapsed: TimeInterval)

    /// Called after a new state was adopted and before it is rendered, for values that
    /// come from the state itself rather than from the clock (e.g. the round count).
    func didAdopt(_ newState: TimerState, replacing previous: TimerState?, at date: Date)

    /// Called on a tick while the workout runs, after `render(elapsed:)`, for feedback
    /// tied to the clock (e.g. interval beeps). Never called for an adopted state, so
    /// joining or resyncing a workout replays nothing.
    func didTick(elapsed: TimeInterval)

    /// Pins the displayed values to their final state once the workout has completed.
    func renderCompletion()

    /// Returns the displayed values to their state before the workout started.
    func resetDisplay()
}

extension TimerStateRendering {
    func didAdopt(_ newState: TimerState, replacing previous: TimerState?, at date: Date) {}
    func didTick(elapsed: TimeInterval) {}
    func renderCompletion() {}
}

// MARK: - Shared behavior

extension TimerStateRendering {
    var isRunning: Bool {
        core.isRunning
    }

    /// Explicit completion signal: true only once the workout reached zero or was declared
    /// done (observed on a tick, or adopted from a completed state), never for a pause or
    /// a stop.
    var didComplete: Bool {
        core.didComplete
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
        didAdopt(newState, replacing: previous, at: date)
        refresh(at: date, isTick: false)
    }

    func reset() {
        core.stopTicking()
        core.state = nil
        core.isRunning = false
        core.didComplete = false
        resetDisplay()
    }

    /// Re-renders from the state at `date`: displayed values, running flag, completion
    /// and ticking.
    private func refresh(at date: Date, isTick: Bool) {
        guard let state = core.state else { return }
        let wasRunning = core.isRunning
        let elapsed = state.elapsed(at: date)
        render(elapsed: elapsed)

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
        if completed {
            renderCompletion()
            if !core.didComplete {
                core.didComplete = true
                if wasRunning {
                    core.feedbackProvider.onWorkoutComplete()
                }
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
