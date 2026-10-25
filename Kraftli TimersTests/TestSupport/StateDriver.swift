//
//  StateDriver.swift
//  Kraftli TimersTests
//
//  Drives a timer model the way `TimerSessionController` does (ADR-006): it owns a
//  `TimerState`, changes it only through `TimerStateReducer`, and hands every new
//  version to the model's `apply(_:)`.
//

import Foundation
@testable import Kraftli_Timers

@MainActor
final class StateDriver {
    private(set) var state: TimerState?
    private let config: TimerConfig
    private let now: () -> Date
    private let apply: (TimerState) -> Void

    init(emom model: EMOMTimerModel, now: @escaping () -> Date) {
        config = TimerConfig(
            timerKindRaw: TimerKind.emom.rawValue,
            totalDuration: model.totalDuration,
            intervalCount: model.totalIntervals,
            exerciseName: "Test"
        )
        self.now = now
        apply = { model.apply($0) }
    }

    init(amrap model: AMRAPTimerModel, now: @escaping () -> Date) {
        config = TimerConfig(
            timerKindRaw: TimerKind.amrap.rawValue,
            totalDuration: model.totalDuration,
            intervalCount: nil,
            exerciseName: "Test"
        )
        self.now = now
        apply = { model.apply($0) }
    }

    /// Starts a new workout whose clock starts at `date` (default: now, no countdown).
    func start(at date: Date? = nil) {
        let state = TimerState(workoutID: UUID(), owner: .phone, config: config, startDate: date ?? now())
        self.state = state
        apply(state)
    }

    func pause(at date: Date? = nil) { act(.pause, at: date) }
    func resume(at date: Date? = nil) { act(.resume, at: date) }
    func incrementRound(at date: Date? = nil) { act(.incrementRound, at: date) }

    private func act(_ action: TimerIntent.Action, at date: Date?) {
        guard let state else { return }
        let date = date ?? now()
        let intent = TimerIntent(workoutID: state.workoutID, baseRevision: state.revision, action: action, at: date)
        // Allow a date slightly ahead of the clock, as the owner would for a remote intent.
        let next = TimerStateReducer.apply([intent], to: state, now: max(now(), date))
        self.state = next
        apply(next)
    }
}
