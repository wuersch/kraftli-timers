//
//  SessionEstimate.swift
//  Kraftli Timers
//
//  How long a session roughly takes, and its shape as a sequence of segments (UC-0013).
//

import Foundation

/// A session's estimated length and its shape: every timer and rest in running order.
///
/// It is a value built once from the elements. A view makes one and reads the segments,
/// the length and the summary from it, instead of working each of them out again. The
/// pace of an exercise comes in as a closure, so tests don't need the bundled library.
struct SessionEstimate: Equatable {
    /// Looks up the seconds one rep of an exercise takes; `nil` if there is none.
    /// Tests pass one; without one, the bundled exercise library is asked.
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
    static func libraryPace(of exerciseId: UUID?) -> Double? {
        guard let exerciseId else { return nil }
        return ExerciseRepository.exercise(byId: exerciseId)?.secondsPerRep
    }

    static func forTimeSeconds(reps: Int, secondsPerRep: Double) -> TimeInterval {
        secondsPerRep * pow(Double(max(reps, 0)), fatigueExponent)
    }

    /// EMOM and AMRAP take their duration; For Time is estimated from its reps.
    static func seconds(of step: SessionStep, pace: Pace? = nil) -> TimeInterval {
        guard step.kind == .forTime else { return step.durationInterval }
        let secondsPerRep = if let pace { pace(step.exerciseId) } else { libraryPace(of: step.exerciseId) }
        return forTimeSeconds(reps: step.targetReps ?? 0, secondsPerRep: secondsPerRep ?? fallbackSecondsPerRep)
    }

    /// The session in running order with every loop unrolled: its steps once per round,
    /// and its rest after each round except the last.
    let segments: [Segment]

    init(of elements: [SessionElement], pace: Pace? = nil) {
        segments = elements.flatMap { element -> [Segment] in
            switch element {
            case .step(let step):
                return [Segment(kind: step.kind, seconds: Self.seconds(of: step, pace: pace), loopID: nil)]
            case .loop(let loop):
                return (0..<loop.rounds).flatMap { round -> [Segment] in
                    var segments = loop.steps.map {
                        Segment(kind: $0.kind, seconds: Self.seconds(of: $0, pace: pace), loopID: loop.id)
                    }
                    if loop.restSeconds > 0, round < loop.rounds - 1 {
                        segments.append(Segment(kind: nil, seconds: TimeInterval(loop.restSeconds), loopID: loop.id))
                    }
                    return segments
                }
            }
        }
    }

    var totalSeconds: TimeInterval {
        segments.reduce(0) { $0 + $1.seconds }
    }

    /// The number of timers the athlete runs: a loop's steps count once per round, and
    /// rests don't count.
    var timerCount: Int {
        segments.count { $0.kind != nil }
    }

    /// "≈ 37 min"
    var lengthText: String {
        Self.text(forSeconds: totalSeconds)
    }

    /// "≈ 37 min · 8 timers"
    var summary: String {
        lengthText + UISeparator.dot + (timerCount == 1 ? "1 timer" : "\(timerCount) timers")
    }

    /// "≈ 37 min": whole minutes, at least one, always marked as approximate.
    static func text(forSeconds seconds: TimeInterval) -> String {
        "≈ \(max(1, Int((seconds / 60).rounded()))) min"
    }
}
