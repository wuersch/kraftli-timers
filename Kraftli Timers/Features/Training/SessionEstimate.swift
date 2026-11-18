//
//  SessionEstimate.swift
//  Kraftli Timers
//
//  How long a session roughly takes, and its shape as a sequence of segments (UC-0013).
//

import Foundation

/// Estimates a session's length. Pure functions: the pace of an exercise comes in as a
/// closure, so tests don't need the bundled library.
enum SessionEstimate {
    /// Looks up the seconds one rep of an exercise takes; `nil` if there is none.
    typealias Pace = (UUID?) -> Double?

    /// A For Time timer takes `pace × reps^1.1`: slightly more than linear, because the
    /// athlete tires.
    static let fatigueExponent = 1.1
    /// The pace for an exercise without one (a hold, or an exercise no longer in the library).
    static let fallbackSecondsPerRep = 3.0

    /// One stretch of a session in running order: a timer, or a rest (`kind == nil`).
    struct Segment: Equatable {
        let kind: TimerKind?
        let seconds: TimeInterval
        /// The loop the segment belongs to, for bracketing a loop in the shape.
        let loopID: UUID?
    }

    /// The pace from the bundled exercise library.
    static let libraryPace: Pace = { id in
        id.flatMap(ExerciseRepository.exercise(byId:))?.secondsPerRep
    }

    static func forTimeSeconds(reps: Int, secondsPerRep: Double) -> TimeInterval {
        secondsPerRep * pow(Double(max(reps, 0)), fatigueExponent)
    }

    /// EMOM and AMRAP take their duration; For Time is estimated from its reps.
    static func seconds(of step: SessionStep, pace: Pace = libraryPace) -> TimeInterval {
        guard step.kind == .forTime else { return step.durationInterval }
        return forTimeSeconds(
            reps: step.targetReps ?? 0,
            secondsPerRep: pace(step.exerciseId) ?? fallbackSecondsPerRep
        )
    }

    /// The session in running order with every loop unrolled: its steps once per round,
    /// and its rest after each round except the last.
    static func segments(of elements: [SessionElement], pace: Pace = libraryPace) -> [Segment] {
        elements.flatMap { element -> [Segment] in
            switch element {
            case .step(let step):
                return [Segment(kind: step.kind, seconds: seconds(of: step, pace: pace), loopID: nil)]
            case .loop(let loop):
                return (0..<loop.rounds).flatMap { round -> [Segment] in
                    var segments = loop.steps.map {
                        Segment(kind: $0.kind, seconds: seconds(of: $0, pace: pace), loopID: loop.id)
                    }
                    if loop.restSeconds > 0, round < loop.rounds - 1 {
                        segments.append(Segment(kind: nil, seconds: TimeInterval(loop.restSeconds), loopID: loop.id))
                    }
                    return segments
                }
            }
        }
    }

    static func totalSeconds(of elements: [SessionElement], pace: Pace = libraryPace) -> TimeInterval {
        segments(of: elements, pace: pace).reduce(0) { $0 + $1.seconds }
    }

    /// The number of timers the athlete runs: a loop's steps count once per round.
    static func timerCount(of elements: [SessionElement]) -> Int {
        elements.reduce(0) { count, element in
            switch element {
            case .step: count + 1
            case .loop(let loop): count + loop.steps.count * loop.rounds
            }
        }
    }

    /// "≈ 37 min": whole minutes, at least one, always marked as approximate.
    static func text(forSeconds seconds: TimeInterval) -> String {
        "≈ \(max(1, Int((seconds / 60).rounded()))) min"
    }

    /// "≈ 37 min · 8 timers"
    static func summary(of elements: [SessionElement], pace: Pace = libraryPace) -> String {
        let count = timerCount(of: elements)
        let timers = count == 1 ? "1 timer" : "\(count) timers"
        return text(forSeconds: totalSeconds(of: elements, pace: pace)) + UISeparator.dot + timers
    }
}
