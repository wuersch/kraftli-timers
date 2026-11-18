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

    // MARK: - Sessions

    @Test func loop_countsItsStepsOncePerRound_andRestsBetweenRounds() {
        let loop = SessionLoop(rounds: 3, restSeconds: 60, steps: [amrap(minutes: 4)])
        let elements: [SessionElement] = [.step(emom(minutes: 5)), .loop(loop)]

        // 5 min + 3 × 4 min + 2 rests of 1 min: no rest after the last round.
        #expect(SessionEstimate.totalSeconds(of: elements, pace: pace) == 300 + 3 * 240 + 2 * 60)
        #expect(SessionEstimate.timerCount(of: elements) == 4)
    }

    @Test func segments_unrollTheLoopInRunningOrder() {
        let loop = SessionLoop(rounds: 2, restSeconds: 30, steps: [amrap(minutes: 1)])
        let segments = SessionEstimate.segments(of: [.step(emom(minutes: 2)), .loop(loop)], pace: pace)

        #expect(segments.map(\.kind) == [.emom, .amrap, nil, .amrap])
        #expect(segments.map(\.seconds) == [120, 60, 30, 60])
        #expect(segments.map(\.loopID) == [nil, loop.id, loop.id, loop.id])
    }

    @Test func loopWithoutRest_hasNoRestSegments() {
        let loop = SessionLoop(rounds: 2, restSeconds: 0, steps: [amrap(minutes: 1)])

        #expect(SessionEstimate.segments(of: [.loop(loop)], pace: pace).map(\.kind) == [.amrap, .amrap])
    }

    // MARK: - Text

    @Test func text_roundsToWholeMinutes_andNeverShowsZero() {
        #expect(SessionEstimate.text(forSeconds: 36.6 * 60) == "≈ 37 min")
        #expect(SessionEstimate.text(forSeconds: 10) == "≈ 1 min")
    }

    @Test func summary_namesTheLengthAndTheTimers() {
        #expect(SessionEstimate.summary(of: [.step(emom(minutes: 5))], pace: pace) == "≈ 5 min · 1 timer")
    }
}

struct SessionDocumentTests {
    @Test func elements_surviveARoundTrip() {
        let step = SessionStep(kind: .forTime, exerciseId: UUID(), durationInterval: 0, targetReps: 30)
        let loop = SessionLoop(rounds: 3, restSeconds: 60, steps: [step])
        let elements: [SessionElement] = [.step(step), .loop(loop)]

        #expect(SessionDocument.elements(from: SessionDocument.data(for: elements)) == elements)
    }

    @Test func missingOrUnreadableData_givesNoElements() {
        #expect(SessionDocument.elements(from: nil).isEmpty)
        #expect(SessionDocument.elements(from: Data("not json".utf8)).isEmpty)
    }

    /// A newer app version may add fields; this one must still read the rest.
    @Test func unknownFields_areIgnored() {
        let json = """
        {"version":2,"note":"x","elements":[{"step":{"id":"\(UUID().uuidString)","kindRawValue":"AMRAP",\
        "durationInterval":300,"colour":"red"}}]}
        """

        let elements = SessionDocument.elements(from: Data(json.utf8))

        #expect(elements.count == 1)
        guard case .step(let step) = elements.first else {
            Issue.record("expected a step")
            return
        }
        #expect(step.kind == .amrap)
        #expect(step.targetReps == nil)
    }
}
