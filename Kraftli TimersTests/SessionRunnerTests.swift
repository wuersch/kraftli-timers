//
//  SessionRunnerTests.swift
//  Kraftli TimersTests
//
//  What running a session records, and when it celebrates (UC-0015).
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct SessionRunnerTests {

    // MARK: - Fixtures

    /// Remembers what the runner asked to be recorded.
    private final class SpyRecorder: WorkoutRecorder {
        private(set) var steps: [(completion: WorkoutCompletionData, exerciseName: String, kind: TimerKind)] = []
        private(set) var sessions: [(runID: UUID, name: String, activeIntervals: [DateInterval])] = []

        func record(
            _ completion: WorkoutCompletionData, exerciseName: String, timerKind: TimerKind
        ) -> Task<Void, Never> {
            steps.append((completion, exerciseName, timerKind))
            return Task {}
        }

        func recordSession(runID: UUID, name: String, activeIntervals: [DateInterval]) -> Task<Void, Never> {
            sessions.append((runID, name, activeIntervals))
            return Task {}
        }
    }

    /// A clock the test moves by hand.
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)
        func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
    }

    private let pushUps = SessionStep(kind: .amrap, exerciseId: nil, durationInterval: 240, targetReps: nil)
    private let squats = SessionStep(kind: .forTime, exerciseId: nil, durationInterval: 0, targetReps: 30)

    private func makeRunner(
        _ elements: [SessionElement]
    ) -> (runner: SessionRunner, recorder: SpyRecorder, clock: Clock) {
        let recorder = SpyRecorder()
        let clock = Clock()
        let runner = SessionRunner(
            name: "Full Body", elements: elements, recorder: recorder,
            now: { clock.now }, schedulesRest: false
        )
        return (runner, recorder, clock)
    }

    private func completion(_ duration: TimeInterval, rounds: Int? = nil, reps: Int? = nil) -> WorkoutCompletionData {
        WorkoutCompletionData(durationSeconds: duration, repsCompleted: reps, roundsCompleted: rounds)
    }

    // MARK: - Recording

    @Test func completedStep_isRecordedAsAStepOfTheSession() {
        let (runner, recorder, clock) = makeRunner([.step(pushUps), .step(squats)])

        runner.startStep()
        clock.advance(243)
        runner.stepCompleted(completion(240, rounds: 9))

        let recorded = recorder.steps[0]
        #expect(recorded.kind == .amrap)
        #expect(recorded.completion.sessionName == "Full Body")
        #expect(recorded.completion.sessionRunID == runner.runID)
        #expect(recorded.completion.correlationID == runner.stepWorkoutID)
        #expect(recorded.completion.roundsCompleted == 9)
        #expect(runner.run.phase == .upNext)
        #expect(recorder.sessions.isEmpty)
    }

    @Test func everyStart_isAWorkoutOfItsOwn() {
        let loop = SessionLoop(rounds: 2, restSeconds: 0, steps: [pushUps])
        let (runner, recorder, _) = makeRunner([.loop(loop)])

        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 9))
        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 8))

        let ids = recorder.steps.map(\.completion.correlationID)
        #expect(ids[0] != ids[1])
        #expect(Set(recorder.steps.map(\.completion.sessionRunID)) == [runner.runID])
    }

    @Test func stepStoppedEarly_isRecorded_andTheSessionGoesOn() {
        let (runner, recorder, _) = makeRunner([.step(pushUps), .step(squats)])
        var stopped = completion(163, rounds: 5)
        stopped.stoppedEarly = true

        runner.startStep()
        runner.stepStopped(stopped)
        // The step's screen closes after reporting; that must not count it twice.
        runner.stepClosed()

        #expect(recorder.steps.count == 1)
        #expect(recorder.steps[0].completion.stoppedEarly)
        #expect(runner.run.results.map(\.outcome) == [.stoppedEarly])
        #expect(runner.run.currentStep == squats)
    }

    @Test func stepEndedTooEarly_isNotRecorded_andTheSessionGoesOn() {
        let (runner, recorder, _) = makeRunner([.step(pushUps), .step(squats)])

        runner.startStep()
        runner.stepClosed()

        #expect(recorder.steps.isEmpty)
        #expect(runner.run.results.map(\.outcome) == [.skipped])
        #expect(runner.run.currentStep == squats)
    }

    @Test func skippedStep_isNotRecorded() {
        let (runner, recorder, _) = makeRunner([.step(pushUps), .step(squats)])

        runner.skip()

        #expect(recorder.steps.isEmpty)
        #expect(runner.run.currentStep == squats)
    }

    // MARK: - End of the session

    @Test func lastTimer_endsTheSession_recordsItOnce_andCelebratesOnce() {
        let (runner, recorder, clock) = makeRunner([.step(pushUps), .step(squats)])
        var celebrations = 0
        runner.onCompleted = { celebrations += 1 }

        runner.startStep()
        clock.advance(243)
        runner.stepCompleted(completion(240, rounds: 9))
        #expect(celebrations == 0)

        clock.advance(100)
        runner.startStep()
        clock.advance(133)
        runner.stepCompleted(completion(130, reps: 30))

        #expect(runner.run.phase == .finished)
        #expect(celebrations == 1)
        #expect(recorder.sessions.count == 1)
        #expect(recorder.sessions[0].runID == runner.runID)
        #expect(recorder.sessions[0].name == "Full Body")
        #expect(recorder.sessions[0].activeIntervals.count == 2)
    }

    @Test func sessionWithASkippedTimer_isRecorded_butNotCelebrated() {
        let (runner, recorder, _) = makeRunner([.step(pushUps), .step(squats)])
        var celebrations = 0
        runner.onCompleted = { celebrations += 1 }

        runner.skip()
        runner.startStep()
        runner.stepCompleted(completion(130, reps: 30))

        #expect(runner.run.phase == .finished)
        #expect(celebrations == 0)
        #expect(recorder.sessions.count == 1)
    }

    @Test func sessionEndedEarly_isRecorded_butNotCelebrated() {
        let (runner, recorder, _) = makeRunner([.step(pushUps), .step(squats)])
        var celebrations = 0
        runner.onCompleted = { celebrations += 1 }

        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 9))
        runner.endSession()

        #expect(runner.run.phase == .finished)
        #expect(celebrations == 0)
        #expect(recorder.sessions.count == 1)
    }

    // MARK: - Rest

    @Test func rest_endsWhenItsTimeIsUp_notBefore() {
        let loop = SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps])
        let (runner, _, clock) = makeRunner([.loop(loop)])
        runner.startStep()
        clock.advance(243)
        runner.stepCompleted(completion(240, rounds: 9))
        #expect(runner.run.phase == .resting(until: clock.now.addingTimeInterval(60)))

        let firstStep = runner.stepWorkoutID
        clock.advance(59)
        runner.checkRest()
        #expect(runner.run.phase != .running)

        // When the rest is up, the next timer starts by itself, as a workout of its own.
        clock.advance(1)
        runner.checkRest()
        #expect(runner.run.phase == .running)
        #expect(runner.run.restTime == 60)
        #expect(runner.stepWorkoutID != firstStep)
    }

    @Test func rest_canBeCutShort() {
        let loop = SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps])
        let (runner, _, clock) = makeRunner([.loop(loop)])
        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 9))

        clock.advance(15)
        runner.skipRest()

        #expect(runner.run.phase == .running)
        #expect(runner.run.restTime == 15)
    }

    @Test func sessionEndedDuringARest_endsTheRestWithIt_andIsRecorded() {
        let loop = SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps])
        let (runner, recorder, clock) = makeRunner([.loop(loop)])
        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 9))

        // The way a session ended on the Watch arrives while the iPhone rests.
        clock.advance(15)
        runner.endSession()

        #expect(runner.run.phase == .finished)
        #expect(runner.run.endedEarly)
        #expect(runner.run.restTime == 15)
        #expect(recorder.sessions.count == 1)
    }

    // MARK: - The Watch (ADR-0012)

    /// A runner whose statuses for the Watch are collected.
    private func makeReportingRunner(
        _ elements: [SessionElement]
    ) -> (runner: SessionRunner, recorder: SpyRecorder, statuses: () -> [SessionStatus]) {
        final class Outbox { var statuses: [SessionStatus] = [] }
        let outbox = Outbox()
        let recorder = SpyRecorder()
        let runner = SessionRunner(
            name: "Full Body", elements: elements, recorder: recorder,
            sendStatus: { outbox.statuses.append($0) }, schedulesRest: false
        )
        return (runner, recorder, { outbox.statuses })
    }

    @Test func everyChangeOfPhase_isReportedToTheWatch_inOrder() {
        let loop = SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps])
        let (runner, _, statuses) = makeReportingRunner([.loop(loop)])

        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 9))
        runner.skipRest()
        runner.stepCompleted(completion(240, rounds: 8))

        let sent = statuses()
        #expect(sent.map(\.sequence) == [1, 2, 3, 4])
        #expect(sent[0].phase == .running)
        if case .resting = sent[1].phase {} else { Issue.record("expected the rest to be reported") }
        #expect(sent[2].phase == .running)
        #expect(sent[3].phase == .finished(save: true))
        #expect(Set(sent.map(\.runID)) == [runner.runID])

        // What is running, and where in the session.
        #expect(sent[0].step?.kind == .amrap)
        #expect(sent[0].step?.totalDuration == 240)
        #expect(sent[2].loopRound == 2)
        #expect(sent[3].step == nil)

        // The session's shape (timer, rest, timer) and the place in it.
        #expect(sent[0].shape.map(\.kind) == [.amrap, nil, .amrap])
        #expect(sent[0].shape.map(\.seconds) == [240, 60, 240])
        #expect(sent.map(\.position).prefix(3) == [0, 1, 2])
    }

    @Test func sessionThatRecordedNothing_tellsTheWatchNotToSave() {
        let (runner, _, statuses) = makeReportingRunner([.step(pushUps)])

        runner.skip()

        #expect(statuses().last?.phase == .finished(save: false))
    }

    @Test func firstStepsOwner_holdsTheHealthWorkout_forTheWholeSession() {
        let (runner, _, _) = makeReportingRunner([.step(pushUps), .step(squats)])
        #expect(runner.startsStepsOnWatch)

        runner.startStep()
        runner.stepOwned(by: .watch)
        runner.stepCompleted(completion(240, rounds: 9))
        // A later step that fell back to the iPhone doesn't change who holds it.
        runner.startStep()
        runner.stepOwned(by: .phone)

        #expect(runner.healthOwner == .watch)
        #expect(runner.startsStepsOnWatch)
    }

    @Test func sessionTheWatchHolds_isNotSavedToHealthByTheiPhone() {
        let (runner, recorder, _) = makeReportingRunner([.step(pushUps)])

        runner.startStep()
        runner.stepOwned(by: .watch)
        runner.stepCompleted(completion(240, rounds: 9))

        #expect(runner.run.phase == .finished)
        #expect(recorder.steps.count == 1)
        #expect(recorder.sessions.isEmpty)
    }

    @Test func sessionTheiPhoneHolds_keepsItsStepsOffTheWatch_andIsSavedByTheiPhone() {
        let (runner, recorder, _) = makeReportingRunner([.step(pushUps), .step(squats)])

        runner.startStep()
        runner.stepOwned(by: .phone)
        #expect(!runner.startsStepsOnWatch)
        runner.stepCompleted(completion(240, rounds: 9))
        runner.endSession()

        #expect(recorder.sessions.count == 1)
    }
}
