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
/// sent through `TimerSessionController.done()` — completes it. It gives no signals
/// during the workout. Adopting states, ticking and completion come from
/// `TimerStateRendering`.
@Observable
final class ForTimeTimerModel: TimerStateRendering {
    // MARK: - Published Properties (MainActor isolated)
    /// Active time so far, pauses excluded; frozen while paused and once finished.
    @MainActor private(set) var elapsedTime: TimeInterval = 0

    // MARK: - Private Properties
    let targetReps: Int
    let core: TimerRenderCore

    // MARK: - Computed Properties

    /// How long the comet takes for one lap: brisk enough to feel urgent, and a divisor of
    /// 60 s, so the head still passes 12 o'clock on every full minute.
    static let lapDuration: TimeInterval = 10

    /// Position within the current lap (0..<1), for the comet that circles the ring.
    @MainActor
    var lapProgress: Double {
        elapsedTime.truncatingRemainder(dividingBy: Self.lapDuration) / Self.lapDuration
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
        self.core = TimerRenderCore(timerProvider: timerProvider, feedbackProvider: feedbackProvider, now: now)
    }

    // MARK: - TimerStateRendering

    @MainActor
    func render(elapsed: TimeInterval) {
        elapsedTime = elapsed
    }

    @MainActor
    func resetDisplay() {
        elapsedTime = 0
    }
}
