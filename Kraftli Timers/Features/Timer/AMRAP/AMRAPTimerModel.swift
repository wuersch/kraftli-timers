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
    let totalDuration: TimeInterval
    let core: TimerRenderCore

    // MARK: - Displayed Values (derived from the core)

    @MainActor
    var totalTimeRemaining: TimeInterval {
        max(0, totalDuration - core.elapsed)
    }

    /// Rounds completed, as counted by the workout's owner (`TimerState.roundCount`).
    /// Taps go through `TimerSessionController.incrementRound()`, never to the model.
    @MainActor
    var roundsCompleted: Int {
        core.roundCount
    }

    @MainActor
    var progress: Double {
        totalTimeRemaining / totalDuration
    }

    @MainActor
    var elapsedTime: TimeInterval {
        core.elapsed
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
        totalDuration: TimeInterval,
        timerProvider: TimerProvider,
        feedbackProvider: FeedbackProvider,
        now: @escaping () -> Date = { Date() }
    ) {
        self.totalDuration = totalDuration
        self.core = TimerRenderCore(timerProvider: timerProvider, feedbackProvider: feedbackProvider, now: now)
    }
}
