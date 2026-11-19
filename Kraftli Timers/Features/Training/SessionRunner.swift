//
//  SessionRunner.swift
//  Kraftli Timers
//
//  Drives one run through a session (UC-0015): starts its steps, records what they
//  came to, counts down the rests and ends the run.
//

import Foundation
import SwiftUI

/// Runs a session on the iPhone.
///
/// The rules live in `SessionRun`, a value; this object adds what a value can't have:
/// the current time, the rest's timer, and the recorder. It is `@Observable`, so the
/// runner's views redraw whenever `run` is replaced by a changed copy.
///
/// Each step is an ordinary workout of its own, with its own ID and timer state
/// (ADR-0006); the runner only decides which comes next and what a finished one means
/// for the session.
@Observable
@MainActor
final class SessionRunner {
    private(set) var run: SessionRun

    /// Identifies this run on the entries of all its steps and on its Health workout.
    let runID = UUID()

    /// The ID of the step that is running or was started last: a new one per start,
    /// because a step in a loop runs several times and each time is a workout of its own.
    private(set) var stepWorkoutID = UUID()

    /// Called once when the run went through to its last timer: time for the completion
    /// sound and confetti. Not called for a session the athlete ended early.
    @ObservationIgnored var onCompleted: (() -> Void)?

    @ObservationIgnored private let recorder: any WorkoutRecorder
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let schedulesRest: Bool
    @ObservationIgnored private var restTask: Task<Void, Never>?
    @ObservationIgnored private var hasFinished = false

    /// - Parameters:
    ///   - name: The session's name, as it is now.
    ///   - elements: The session's elements, as they are now. The run keeps this copy.
    ///   - recorder: Writes the steps' history entries and the session's Health workout.
    ///   - now: Wall-clock source. Injectable so tests can drive time.
    ///   - schedulesRest: Whether to end a rest by itself when its time is up. Tests turn
    ///     it off and call `checkRest()` directly.
    init(
        name: String,
        elements: [SessionElement],
        recorder: any WorkoutRecorder,
        now: @escaping () -> Date = { Date() },
        schedulesRest: Bool = true
    ) {
        self.run = SessionRun(name: name, elements: elements)
        self.recorder = recorder
        self.now = now
        self.schedulesRest = schedulesRest
    }

    // MARK: - Between steps

    /// The athlete starts the step that is up next.
    func startStep() {
        guard run.phase == .upNext else { return }
        stepWorkoutID = UUID()
        run.startStep(at: now())
    }

    func skip() {
        run.skip(at: now())
        phaseChanged()
    }

    func endSession() {
        run.endSession(at: now())
        phaseChanged()
    }

    // MARK: - A step ended

    /// The step's timer ran out, or its For Time was declared done.
    func stepCompleted(_ completion: WorkoutCompletionData) {
        stepEnded(.completed, completion)
    }

    /// The step was ended early with enough active time to be recorded.
    func stepStopped(_ completion: WorkoutCompletionData) {
        stepEnded(.stoppedEarly, completion)
    }

    /// The step's screen closed. If the step is still counted as running, it was ended
    /// too early to be recorded: the session moves on as after a skip.
    func stepClosed() {
        guard run.phase == .running else { return }
        run.stepEnded(.skipped, at: now())
        phaseChanged()
    }

    private func stepEnded(_ outcome: SessionRun.Outcome, _ completion: WorkoutCompletionData) {
        guard run.phase == .running, let step = run.currentItem?.step else { return }
        var completion = completion
        completion.correlationID = stepWorkoutID
        completion.sessionName = run.name
        completion.sessionRunID = runID
        recorder.record(completion, exerciseName: step.exerciseName, timerKind: step.kind)

        run.stepEnded(
            outcome,
            duration: completion.durationSeconds,
            reps: completion.repsCompleted,
            roundsCounted: completion.roundsCompleted,
            at: now()
        )
        phaseChanged()
    }

    // MARK: - Rest

    /// The athlete cuts the rest short.
    func skipRest() {
        run.restEnded(at: now())
        phaseChanged()
    }

    /// Ends the rest if its time is up. Scheduled when a rest begins; also called when
    /// the app returns to the foreground, where a suspended timer may be late.
    func checkRest() {
        guard case .resting(let until) = run.phase, now() >= until else { return }
        run.restEnded(at: now())
        phaseChanged()
    }

    // MARK: - Private

    /// Follows up on a change of phase: a rest gets its timer, a finished run is recorded.
    private func phaseChanged() {
        restTask?.cancel()
        restTask = nil

        switch run.phase {
        case .resting(let until):
            guard schedulesRest else { return }
            restTask = Task { [weak self, now] in
                try? await Task.sleep(for: .seconds(max(until.timeIntervalSince(now()), 0)))
                guard !Task.isCancelled else { return }
                self?.checkRest()
            }
        case .finished:
            guard !hasFinished else { return }
            hasFinished = true
            recorder.recordSession(runID: runID, name: run.name, activeIntervals: run.activeIntervals)
            if run.endedAtItsLastTimer {
                onCompleted?()
            }
        case .upNext, .running:
            break
        }
    }
}

/// A step's sounds without its completion sound: a session plays that once, after its
/// last timer. Countdown beeps and interval signals pass through.
struct StepFeedback: FeedbackProvider {
    let base: any FeedbackProvider

    func onCountdownCount() { base.onCountdownCount() }
    func onIntervalComplete() { base.onIntervalComplete() }
    func onWarning() { base.onWarning() }
    func onWorkoutComplete() {}
}
