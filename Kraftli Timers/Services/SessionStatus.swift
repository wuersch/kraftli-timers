//
//  SessionStatus.swift
//  Kraftli Timers
//
//  What the iPhone tells the Watch about a running training session (ADR-0012).
//

import Foundation

/// Names the run of a session a workout is a step of. Travels with the step's start
/// request, so the Watch can tell a step of the run it already holds from a new workout.
nonisolated struct SessionContext: Codable, Equatable, Sendable {
    /// The run, as on the history entries of its steps (`WorkoutLog.sessionRunID`).
    let runID: UUID
    let name: String
}

/// The progress of a session's run, sent by the iPhone on every change of phase.
///
/// One-way: the Watch never answers and never changes a session (ADR-0012). From it the
/// Watch pauses, resumes and ends the Health session it holds for the run, and shows
/// what comes next.
nonisolated struct SessionStatus: Codable, Equatable, Sendable {
    enum Phase: Codable, Equatable, Sendable {
        /// Between steps, waiting for the athlete: the session is paused.
        case upNext
        /// A step's timer is running.
        case running
        /// A loop's rest counts down to `until`: the session is not paused.
        case resting(until: Date)
        /// The session is over. `save` is false when it left nothing to record.
        case finished(save: Bool)
    }

    /// One stretch of the run in running order, for drawing the session's shape: a timer,
    /// or a loop's rest (`kind == nil`).
    struct Segment: Codable, Equatable, Sendable {
        let kind: TimerKind?
        let seconds: TimeInterval
    }

    let runID: UUID
    let name: String
    /// Counts up with every status of a run. The same status arrives over several
    /// channels and possibly late; receivers keep only one newer than the last.
    let sequence: Int
    let phase: Phase

    /// The timer that is up next, running, or follows the rest; `nil` once finished.
    var step: TimerConfig?
    /// Its round in a loop, and the loop's rounds; `nil` outside a loop.
    var loopRound: Int?
    var loopRounds: Int?
    /// The run's shape, and the index of the segment the run is at.
    var shape: [Segment] = []
    var position = 0

    /// True while the session's Health workout should be running rather than paused.
    var isActive: Bool {
        switch phase {
        case .running, .resting: true
        case .upNext, .finished: false
        }
    }
}
