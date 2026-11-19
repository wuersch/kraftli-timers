//
//  WatchSessionFollower.swift
//  Kraftli Timers
//
//  The Watch's part in a training session run on the iPhone (UC-0015, ADR-0012).
//

import Foundation
import os

/// Holds the Health workout of a session's run on the Watch and follows the run's
/// progress as the iPhone reports it.
///
/// A session's steps are separate workouts, each with its own timer state. What spans
/// them on the Watch is only this: one Health session, kept open from the first step the
/// Watch owns until the iPhone says the session is finished. It runs while a step or a
/// loop's rest runs and is paused in between.
///
/// HealthKit is reached through closures, like in `WatchWorkoutStarter`, so the rules are
/// tested without it.
@Observable
@MainActor
final class WatchSessionFollower {
    /// The run whose Health workout this Watch holds; `nil` when it holds none.
    private(set) var held: SessionContext?

    /// The latest status of the held run, for showing what comes next.
    private(set) var status: SessionStatus?

    @ObservationIgnored private let pauseHealthSession: () -> Void
    @ObservationIgnored private let resumeHealthSession: () -> Void
    @ObservationIgnored private let saveHealthSession: (SessionContext) -> Void
    @ObservationIgnored private let discardHealthSession: () -> Void

    /// - Parameters:
    ///   - pauseHealthSession / resumeHealthSession: Pause and resume the running session.
    ///   - saveHealthSession: Ends the session, saves its workout and reports it to the
    ///     iPhone under the run's ID.
    ///   - discardHealthSession: Ends the session without saving it.
    init(
        pauseHealthSession: @escaping () -> Void,
        resumeHealthSession: @escaping () -> Void,
        saveHealthSession: @escaping (SessionContext) -> Void,
        discardHealthSession: @escaping () -> Void
    ) {
        self.pauseHealthSession = pauseHealthSession
        self.resumeHealthSession = resumeHealthSession
        self.saveHealthSession = saveHealthSession
        self.discardHealthSession = discardHealthSession
    }

    /// True when this Watch holds the Health workout of the run `runID`.
    func isHolding(_ runID: UUID) -> Bool {
        held?.runID == runID
    }

    /// The Watch took ownership of a step of `context`'s run, with a Health session
    /// running: from now on that session belongs to the run, not to the step.
    func hold(_ context: SessionContext) {
        guard held != context else { return }
        Logger.workoutSession.info("Holding the Health session for session run \(context.runID)")
        held = context
        status = nil
    }

    /// The Health session is gone or belongs to something else now (a workout started
    /// on the Watch took it over): stop following the run.
    func release() {
        held = nil
        status = nil
    }

    /// The iPhone reports how far the run has come.
    func receive(_ status: SessionStatus) {
        guard let held, held.runID == status.runID else { return }
        self.status = status

        switch status.phase {
        case .upNext:
            pauseHealthSession()
        case .running, .resting:
            resumeHealthSession()
        case .finished(let save):
            Logger.workoutSession.info("Session run \(held.runID) finished; \(save ? "saving" : "discarding") its Health session")
            if save {
                saveHealthSession(held)
            } else {
                discardHealthSession()
            }
            release()
        }
    }
}
