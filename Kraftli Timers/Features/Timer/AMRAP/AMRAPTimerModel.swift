//
//  AMRAPTimerModel.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

/// Renders an AMRAP workout from a `TimerState` (ADR-006): the time remaining and the
/// round count. Adopting states, ticking and completion come from `TimerStateRendering`.
@Observable
final class AMRAPTimerModel: TimerStateRendering {
    // MARK: - Published Properties (MainActor isolated)
    @MainActor private(set) var totalTimeRemaining: TimeInterval
    /// Rounds completed, as counted by the workout's owner (`TimerState.roundCount`).
    /// Taps go through `TimerSessionController.incrementRound()`, never to the model.
    @MainActor private(set) var roundsCompleted = 0

    // MARK: - Private Properties
    let totalDuration: TimeInterval
    let core: TimerRenderCore

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
    @MainActor
    var isCompleted: Bool {
        totalTimeRemaining <= 0
    }

    /// A time-boxed workout records its full duration.
    var recordedDuration: TimeInterval {
        totalDuration
    }

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
        self.core = TimerRenderCore(timerProvider: timerProvider, feedbackProvider: feedbackProvider, now: now)
        self.totalTimeRemaining = totalDuration
    }

    // MARK: - TimerStateRendering

    /// The round count comes from the state, counted by the workout's owner.
    @MainActor
    func didAdopt(_ newState: TimerState, replacing previous: TimerState?, at date: Date) {
        roundsCompleted = newState.roundCount
    }

    @MainActor
    func render(elapsed: TimeInterval) {
        totalTimeRemaining = max(0, totalDuration - elapsed)
    }

    @MainActor
    func renderCompletion() {
        totalTimeRemaining = 0
    }

    @MainActor
    func resetDisplay() {
        totalTimeRemaining = totalDuration
        roundsCompleted = 0
    }
}
