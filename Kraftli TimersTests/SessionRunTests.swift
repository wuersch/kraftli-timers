//
//  SessionRunTests.swift
//  Kraftli TimersTests
//
//  The rules of running a session (UC-0015), on plain values and dates.
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct SessionRunTests {

    // MARK: - Fixtures

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    private let warmUp = SessionStep(kind: .emom, exerciseId: nil, durationInterval: 300, targetReps: 50)
    private let pushUps = SessionStep(kind: .amrap, exerciseId: nil, durationInterval: 240, targetReps: nil)
    private let squats = SessionStep(kind: .forTime, exerciseId: nil, durationInterval: 0, targetReps: 30)
    private let finisher = SessionStep(kind: .emom, exerciseId: nil, durationInterval: 600, targetReps: 100)

    private func loop(rounds: Int = 3, rest: Int = 60) -> SessionLoop {
        SessionLoop(rounds: rounds, restSeconds: rest, steps: [pushUps, squats])
    }

    /// Warm-up, then three rounds of push-ups and squats with a minute's rest, then a finisher.
    private func fullBody() -> SessionRun {
        SessionRun(name: "Full Body", elements: [.step(warmUp), .loop(loop()), .step(finisher)])
    }

    /// Starts the step that is up next at `start` and completes it `duration` later.
    private func complete(_ run: inout SessionRun, from start: TimeInterval, duration: TimeInterval) {
        run.startStep(at: at(start))
        run.stepEnded(.completed, duration: duration, at: at(start + duration))
    }

    // MARK: - Running order

    @Test func order_unrollsLoops_withARestAfterEachRoundButTheLast() {
        let items = SessionOrder.items(of: [.step(warmUp), .loop(loop()), .step(finisher)])

        #expect(items.map(\.step?.id) == [
            warmUp.id,
            pushUps.id, squats.id, nil,
            pushUps.id, squats.id, nil,
            pushUps.id, squats.id,
            finisher.id
        ])
        #expect(items[1].loopRound == 1)
        #expect(items[4].loopRound == 2)
        #expect(items[7].loopRounds == 3)
        #expect(items[0].loopRound == nil)
    }

    @Test func order_isTheOneTheEstimateDraws() {
        let elements: [SessionElement] = [.step(warmUp), .loop(loop()), .step(finisher)]

        let order = SessionOrder.items(of: elements)
        let segments = SessionEstimate(of: elements).segments

        #expect(segments.map(\.kind) == order.map { $0.step?.kind })
        #expect(segments.map(\.loopID) == order.map(\.loopID))
    }

    @Test func run_neverWaitsOnARestWithoutATimerBeforeAndAfterIt() {
        let emptyLoop = SessionLoop(rounds: 3, restSeconds: 30, steps: [])
        let run = SessionRun(name: "Odd", elements: [.loop(emptyLoop), .step(warmUp)])

        #expect(run.items.map(\.isRest) == [false])
    }

    // MARK: - Position

    @Test func newRun_waitsForTheFirstTimer() {
        let run = fullBody()

        #expect(run.phase == .upNext)
        #expect(run.currentStep == warmUp)
        #expect(run.timerNumber == 1)
        #expect(run.timerCount == 8)
        #expect(run.currentLoopRound == nil)
        #expect(run.lastResult == nil)
    }

    @Test func emptySession_isFinishedAtOnce() {
        #expect(SessionRun(name: "Empty", elements: []).phase == .finished)
    }

    @Test func completedTimer_showsItsResult_andTheNextTimer() {
        var run = fullBody()

        run.startStep(at: at(0))
        #expect(run.phase == .running)
        run.stepEnded(.completed, duration: 300, reps: 50, at: at(303))

        #expect(run.phase == .upNext)
        #expect(run.currentStep == pushUps)
        #expect(run.timerNumber == 2)
        #expect(run.currentLoopRound?.round == 1)
        #expect(run.currentLoopRound?.of == 3)
        #expect(run.lastResult?.step == warmUp)
        #expect(run.lastResult?.reps == 50)
        #expect(run.lastResult?.outcome == .completed)
    }

    // MARK: - Loops and rests

    @Test func lastTimerOfARound_isFollowedByTheRest_thenTheLoopsFirstTimerAgain() {
        var run = fullBody()
        complete(&run, from: 0, duration: 300)
        complete(&run, from: 400, duration: 240)

        run.startStep(at: at(700))
        run.stepEnded(.completed, duration: 130, reps: 30, at: at(833))

        #expect(run.phase == .resting(until: at(893)))
        // During the rest, the timer that follows it is the one announced.
        #expect(run.currentStep == pushUps)
        #expect(run.currentLoopRound?.round == 2)

        // The timer after the rest starts by itself.
        run.restEnded(at: at(893))
        #expect(run.phase == .running)
        #expect(run.currentStep == pushUps)
        #expect(run.timerNumber == 4)
        #expect(run.restTime == 60)
    }

    @Test func restCutShort_countsOnlyTheTimeRested() {
        var run = SessionRun(name: "Loop", elements: [.loop(SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps]))])
        complete(&run, from: 0, duration: 240)

        run.restEnded(at: at(260))

        #expect(run.restTime == 20)
        #expect(run.phase == .running)
    }

    @Test func restThatRanOutUnnoticed_endedWhenItWasDue() {
        var run = SessionRun(name: "Loop", elements: [.loop(SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps]))])
        complete(&run, from: 0, duration: 240)

        // The app comes back ten minutes later: no timer starts behind the athlete's back.
        run.restEnded(at: at(900))

        #expect(run.phase == .upNext)
        #expect(run.restTime == 60)
        #expect(run.activeIntervals == [DateInterval(start: at(0), end: at(300))])
    }

    @Test func lastRound_hasNoRest() {
        var run = SessionRun(name: "Loop", elements: [.loop(SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps]))])
        complete(&run, from: 0, duration: 240)
        run.restEnded(at: at(300))

        complete(&run, from: 400, duration: 240)

        #expect(run.phase == .finished)
    }

    // MARK: - Skipping and ending

    @Test func skippedTimer_isNotRecorded_andTheNextOneIsUp() {
        var run = fullBody()

        run.skip(at: at(0))

        #expect(run.phase == .upNext)
        #expect(run.currentStep == pushUps)
        #expect(run.lastResult?.outcome == .skipped)
        #expect(run.recordedCount == 0)
        #expect(run.activeIntervals.isEmpty)
    }

    @Test func skippingTheLastTimerOfARound_skipsItsRestToo() {
        var run = fullBody()
        complete(&run, from: 0, duration: 300)
        complete(&run, from: 400, duration: 240)

        run.skip(at: at(700))

        #expect(run.phase == .upNext)
        #expect(run.currentStep == pushUps)
        #expect(run.currentLoopRound?.round == 2)
        #expect(run.restTime == 0)
    }

    @Test func skippingTheLastTimer_finishesTheSession_asItsLastTimerWould() {
        var run = SessionRun(name: "Two", elements: [.step(warmUp), .step(finisher)])
        complete(&run, from: 0, duration: 300)

        run.skip(at: at(400))

        #expect(run.phase == .finished)
        #expect(!run.endedEarly)
    }

    @Test func onlyASessionDoneInFull_countsAsCompleted() {
        var full = SessionRun(name: "Two", elements: [.step(warmUp), .step(finisher)])
        complete(&full, from: 0, duration: 300)
        #expect(!full.wasCompletedInFull)
        complete(&full, from: 400, duration: 600)
        #expect(full.wasCompletedInFull)

        var skipped = SessionRun(name: "Two", elements: [.step(warmUp), .step(finisher)])
        skipped.skip(at: at(0))
        complete(&skipped, from: 10, duration: 600)
        #expect(!skipped.wasCompletedInFull)

        var stopped = SessionRun(name: "Two", elements: [.step(warmUp), .step(finisher)])
        complete(&stopped, from: 0, duration: 300)
        stopped.startStep(at: at(400))
        stopped.stepEnded(.stoppedEarly, duration: 100, at: at(503))
        #expect(stopped.phase == .finished)
        #expect(!stopped.wasCompletedInFull)
    }

    @Test func endingTheSession_keepsWhatWasDone_andIsNoCompletion() {
        var run = fullBody()
        complete(&run, from: 0, duration: 300)

        run.endSession(at: at(400))

        #expect(run.phase == .finished)
        #expect(run.endedEarly)
        #expect(!run.wasCompletedInFull)
        #expect(run.recordedCount == 1)
    }

    @Test func session_canOnlyBeEndedOrSkippedBetweenSteps() {
        var run = fullBody()
        run.startStep(at: at(0))

        run.endSession(at: at(10))
        run.skip(at: at(10))

        #expect(run.phase == .running)
        #expect(run.results.isEmpty)
    }

    @Test func timerStoppedEarly_returnsToTheSession() {
        var run = fullBody()
        run.startStep(at: at(0))

        run.stepEnded(.stoppedEarly, duration: 163, reps: 2, at: at(170))

        #expect(run.phase == .upNext)
        #expect(run.lastResult?.outcome == .stoppedEarly)
        #expect(run.recordedCount == 1)
        #expect(run.totalTime == 163)
    }

    @Test func timerEndedTooEarlyToRecord_countsLikeASkip() {
        var run = fullBody()
        run.startStep(at: at(0))

        run.stepEnded(.skipped, duration: 20, at: at(23))

        #expect(run.recordedCount == 0)
        #expect(run.totalTime == 0)
        #expect(run.currentStep == pushUps)
    }

    // MARK: - Time

    @Test func totalTime_isTheTimersAndTheRests_withoutTheWaits() {
        var run = SessionRun(name: "Loop", elements: [.loop(SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps]))])
        complete(&run, from: 0, duration: 240)
        run.restEnded(at: at(300))
        run.stepEnded(.completed, duration: 240, at: at(543))

        #expect(run.totalTime == 540)
    }

    @Test func activeStretches_runFromAStepsStartThroughItsRest_andTheGapsArePauses() {
        var run = SessionRun(name: "Loop", elements: [
            .step(warmUp), .loop(SessionLoop(rounds: 2, restSeconds: 60, steps: [pushUps]))
        ])
        complete(&run, from: 0, duration: 300)          // 0…300, then a wait
        complete(&run, from: 400, duration: 240)        // 400…640, then the rest
        run.restEnded(at: at(700))                      // …700, and the next timer starts
        run.stepEnded(.completed, duration: 240, at: at(943))

        #expect(run.activeIntervals == [
            DateInterval(start: at(0), end: at(300)),
            DateInterval(start: at(400), end: at(943))
        ])
        #expect(run.pauses == [DateInterval(start: at(300), end: at(400))])
        #expect(run.phase == .finished)
        #expect(run.wasCompletedInFull)
    }
}
