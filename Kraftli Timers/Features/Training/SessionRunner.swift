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
/// the current time, the timer of a rest or changeover, and the recorder. It is `@Observable`, so the
/// runner's views redraw whenever `run` is replaced by a changed copy.
///
/// Each step is an ordinary workout of its own, with its own ID and timer state
/// (ADR-0006); the runner only decides which comes next and what a finished one means
/// for the session. The Watch is told the session's progress, one way (ADR-0012).
@Observable
@MainActor
final class SessionRunner {
    private(set) var run: SessionRun

    /// Identifies this run on the entries of all its steps and on its Health workout.
    let runID = UUID()

    /// The ID of the step that is running or was started last: a new one per start,
    /// because a step in a loop runs several times and each time is a workout of its own.
    private(set) var stepWorkoutID = UUID()

    /// Called once when the session was done in full: time for the completion sound and
    /// confetti. Not called when a timer was skipped or stopped early, or the session ended early.
    @ObservationIgnored var onCompleted: (() -> Void)?

    /// The device that holds the session's Health workout: the owner of the first step
    /// whose timer started, fixed from then on (ADR-0012 rule 2). `nil` until then.
    private(set) var healthOwner: DeviceRole?

    /// Whether the next step asks the Watch to run it. Not once the iPhone holds the
    /// Health workout: a Watch joining later would start a second one.
    var startsStepsOnWatch: Bool {
        healthOwner != .phone
    }

    /// Names this run on its steps' start requests.
    var context: SessionContext {
        SessionContext(runID: runID, name: run.name)
    }

    @ObservationIgnored private let recorder: any WorkoutRecorder
    @ObservationIgnored private let sendStatus: (SessionStatus) -> Void
    @ObservationIgnored private var statusSequence = 0
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let schedulesRest: Bool
    @ObservationIgnored private var restTask: Task<Void, Never>?
    @ObservationIgnored private var hasFinished = false

    /// - Parameters:
    ///   - name: The session's name, as it is now.
    ///   - elements: The session's elements, as they are now. The run keeps this copy.
    ///   - recorder: Writes the steps' history entries and the session's Health workout.
    ///   - sendStatus: Sends the session's progress to the Watch.
    ///   - now: Wall-clock source. Injectable so tests can drive time.
    ///   - schedulesRest: Whether to end a rest or changeover by itself when its time is
    ///     up. Tests turn it off and call `checkTimedPhase()` directly.
    init(
        name: String,
        elements: [SessionElement],
        recorder: any WorkoutRecorder,
        sendStatus: @escaping (SessionStatus) -> Void = { _ in },
        now: @escaping () -> Date = { Date() },
        schedulesRest: Bool = true
    ) {
        self.run = SessionRun(name: name, elements: elements)
        self.recorder = recorder
        self.sendStatus = sendStatus
        self.now = now
        self.schedulesRest = schedulesRest
    }

    // MARK: - Between steps

    /// The athlete starts the step that is up next.
    func startStep() {
        guard run.phase == .upNext else { return }
        stepWorkoutID = UUID()
        run.startStep(at: now())
        phaseChanged()
    }

    /// The running step's timer has an owner. The first one settles who holds the
    /// session's Health workout.
    func stepOwned(by owner: DeviceRole) {
        guard healthOwner == nil, run.phase == .running else { return }
        healthOwner = owner
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

    /// The screen of the step started as `workoutID` closed. If that step is still
    /// counted as running, it was ended too early to be recorded: the session moves on
    /// as after a skip. A screen that closes late, after the loop's next step began, is
    /// told apart by its ID.
    func stepClosed(_ workoutID: UUID) {
        guard run.phase == .running, workoutID == stepWorkoutID else { return }
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
        endRest()
    }

    /// Ends the rest or changeover if its time is up. Scheduled when one begins; also
    /// called when the app returns to the foreground, where a suspended timer may be late.
    func checkTimedPhase() {
        switch run.phase {
        case .resting(let until), .changeover(let until):
            guard now() >= until else { return }
            endRest()
        case .upNext, .running, .finished:
            break
        }
    }

    /// Ends the rest or changeover. The timer after it normally starts by itself, as a
    /// workout of its own.
    private func endRest() {
        run.restEnded(at: now())
        run.changeoverEnded(at: now())
        if run.phase == .running {
            stepWorkoutID = UUID()
        }
        phaseChanged()
    }

    // MARK: - Private

    /// Follows up on a change of phase: the Watch is told, a rest gets its timer, a
    /// finished run is recorded.
    private func phaseChanged() {
        restTask?.cancel()
        restTask = nil
        publishStatus()

        switch run.phase {
        case .resting(let until), .changeover(let until):
            guard schedulesRest else { return }
            restTask = Task { [weak self, now] in
                try? await Task.sleep(for: .seconds(max(until.timeIntervalSince(now()), 0)))
                guard !Task.isCancelled else { return }
                self?.checkTimedPhase()
            }
        case .finished:
            guard !hasFinished else { return }
            hasFinished = true
            // The Watch saves the workout of a run it holds (told so by the status).
            if healthOwner != .watch {
                recorder.recordSession(runID: runID, name: run.name, activeIntervals: run.activeIntervals)
            }
            if run.wasCompletedInFull {
                onCompleted?()
            }
        case .upNext, .running:
            break
        }
    }
}

extension SessionRunner {
    /// Tells the Watch where the run is. Numbered, because it travels over several
    /// channels and the Watch keeps only what is newer than the last one.
    private func publishStatus() {
        statusSequence += 1
        let phase: SessionStatus.Phase = switch run.phase {
        case .upNext: .upNext
        case .running: .running
        // Sent as a rest, which is what it is to the Watch's Health session and to a
        // Watch app that doesn't know changeovers; `isChangeover` tells the two apart.
        case .resting(let until), .changeover(let until): .resting(until: until)
        case .finished: .finished(save: run.recordedCount > 0)
        }
        var status = SessionStatus(runID: runID, name: run.name, sequence: statusSequence, phase: phase)
        status.shape = run.segments.map { SessionStatus.Segment(kind: $0.kind, seconds: $0.seconds) }
        status.position = run.position
        if case .changeover = run.phase {
            status.isChangeover = true
        }
        status.loopStepCount = run.openingLoop?.steps.count
        if let step = run.currentStep {
            status.step = step.timerConfig
            status.loopRound = run.currentLoopRound?.round
            status.loopRounds = run.currentLoopRound?.of
        }
        sendStatus(status)
    }
}

extension SessionStep {
    /// The step as the timer it runs: what a preset of the same settings would start.
    var timerConfig: TimerConfig {
        TimerConfig(kind: kind, duration: durationInterval, targetReps: targetReps, exerciseName: exerciseName)
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
