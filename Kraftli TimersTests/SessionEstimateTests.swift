//
//  SessionEstimateTests.swift
//  Kraftli TimersTests
//
//  The estimated length and the shape of a session (UC-0013).
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct SessionEstimateTests {
    private let burpees = UUID()
    /// 5 s per burpee; no pace for anything else.
    private var pace: SessionEstimate.Pace {
        { [burpees] id in id == burpees ? 5 : nil }
    }

    private func emom(minutes: Int) -> SessionStep {
        SessionStep(kind: .emom, exerciseId: nil, durationInterval: TimeInterval(minutes * 60), targetReps: 10)
    }

    private func amrap(minutes: Int) -> SessionStep {
        SessionStep(kind: .amrap, exerciseId: nil, durationInterval: TimeInterval(minutes * 60), targetReps: nil)
    }

    private func forTime(reps: Int, exerciseId: UUID?) -> SessionStep {
        SessionStep(kind: .forTime, exerciseId: exerciseId, durationInterval: 0, targetReps: reps)
    }

    // MARK: - Steps

    @Test func timeBoxedStep_takesItsDuration() {
        #expect(SessionEstimate.seconds(of: emom(minutes: 5), pace: pace) == 300)
        #expect(SessionEstimate.seconds(of: amrap(minutes: 4), pace: pace) == 240)
    }

    @Test func forTimeStep_growsSlightlyFasterThanItsReps() {
        let thirty = SessionEstimate.seconds(of: forTime(reps: 30, exerciseId: burpees), pace: pace)
        let sixty = SessionEstimate.seconds(of: forTime(reps: 60, exerciseId: burpees), pace: pace)

        #expect(abs(thirty - 5 * pow(30, 1.1)) < 0.001)
        #expect(thirty > 150)           // more than the linear 30 × 5 s
        #expect(sixty > 2 * thirty)     // twice the reps take more than twice as long
    }

    @Test func forTimeStep_withoutAPace_usesTheFallback() {
        let seconds = SessionEstimate.seconds(of: forTime(reps: 10, exerciseId: UUID()), pace: pace)

        #expect(abs(seconds - 3 * pow(10, 1.1)) < 0.001)
    }

    @Test func forTimeStep_withoutReps_takesNoTime() {
        #expect(SessionEstimate.seconds(of: forTime(reps: 0, exerciseId: burpees), pace: pace) == 0)
        #expect(SessionEstimate.seconds(of: forTime(reps: -5, exerciseId: burpees), pace: pace) == 0)
    }

    // MARK: - Sessions

    @Test func loop_countsItsStepsOncePerRound_andRestsBetweenRounds() {
        let loop = SessionLoop(rounds: 3, restSeconds: 60, steps: [amrap(minutes: 4)])
        let estimate = SessionEstimate(of: [.step(emom(minutes: 5)), .loop(loop)], pace: pace)

        // 5 min + 3 × 4 min + 2 rests of 1 min: no rest after the last round.
        #expect(estimate.totalSeconds == 300 + 3 * 240 + 2 * 60)
        // Rests are segments, but not timers.
        #expect(estimate.timerCount == 4)
    }

    @Test func segments_unrollTheLoopInRunningOrder() {
        let loop = SessionLoop(rounds: 2, restSeconds: 30, steps: [amrap(minutes: 1)])
        let segments = SessionEstimate(of: [.step(emom(minutes: 2)), .loop(loop)], pace: pace).segments

        #expect(segments.map(\.kind) == [.emom, .amrap, nil, .amrap])
        #expect(segments.map(\.seconds) == [120, 60, 30, 60])
        #expect(segments.map(\.loopID) == [nil, loop.id, loop.id, loop.id])
    }

    @Test func loopWithoutRest_hasNoRestSegments() {
        let loop = SessionLoop(rounds: 2, restSeconds: 0, steps: [amrap(minutes: 1)])

        #expect(SessionEstimate(of: [.loop(loop)], pace: pace).segments.map(\.kind) == [.amrap, .amrap])
    }

    @Test func sessionWithoutElements_isEmpty() {
        let estimate = SessionEstimate(of: [], pace: pace)

        #expect(estimate.segments.isEmpty)
        #expect(estimate.totalSeconds == 0)
        #expect(estimate.timerCount == 0)
    }

    // MARK: - Text

    @Test func text_roundsToWholeMinutes_andNeverShowsZero() {
        #expect(SessionEstimate.text(forSeconds: 36.6 * 60) == "≈ 37 min")
        #expect(SessionEstimate.text(forSeconds: 10) == "≈ 1 min")
    }

    @Test func summary_namesTheLengthAndTheTimers() {
        let one = SessionEstimate(of: [.step(emom(minutes: 5))], pace: pace)
        let two = SessionEstimate(of: [.step(emom(minutes: 5)), .step(amrap(minutes: 4))], pace: pace)

        #expect(one.lengthText == "≈ 5 min")
        #expect(one.summary == "≈ 5 min · 1 timer")
        #expect(two.summary == "≈ 9 min · 2 timers")
    }
}
