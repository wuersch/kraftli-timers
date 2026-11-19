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

        clock.advance(59)
        runner.checkRest()
        #expect(runner.run.phase != .upNext)

        clock.advance(1)
        runner.checkRest()
        #expect(runner.run.phase == .upNext)
        #expect(runner.run.restTime == 60)
    }

    @Test func rest_canBeCutShort() {
        let loop = SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps])
        let (runner, _, clock) = makeRunner([.loop(loop)])
        runner.startStep()
        runner.stepCompleted(completion(240, rounds: 9))

        clock.advance(15)
        runner.skipRest()

        #expect(runner.run.phase == .upNext)
        #expect(runner.run.restTime == 15)
    }
}
