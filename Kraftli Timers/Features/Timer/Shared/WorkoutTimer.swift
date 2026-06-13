//
//  WorkoutTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

protocol WorkoutTimer: AnyObject {
    var totalTimeRemaining: TimeInterval { get }
    var totalDuration: TimeInterval { get }
    var isRunning: Bool { get }

    /// Explicit completion signal, set by the model **only** inside its tick `update()` when the
    /// timer legitimately reaches zero while running. Completion observers key off this rather than
    /// inferring it from `totalTimeRemaining` crossing zero — so a `pause(at:)` clamp or a stray
    /// post-pause tick can no longer "complete" the workout. Reset by `reset()`/`start()`.
    var didComplete: Bool { get }

    /// Reps completed (EMOM timers)
    var completedReps: Int? { get }
    /// Rounds completed (AMRAP timers)
    var completedRounds: Int? { get }

    func start()
    func pause()
    func reset()

    /// Pauses the timer, freezing `remaining` as measured at the supplied authoritative `date`
    /// rather than at each device's local clock.
    ///
    /// `date` is HealthKit's canonical workout-session transition time, which is identical on
    /// iPhone and Watch. Freezing against it keeps both devices' `remaining` in lockstep, so
    /// repeated pause/resume no longer drifts. Only acts while running.
    func pause(at date: Date)

    /// Resumes the timer, re-anchoring `startDate` from the supplied authoritative `date` and
    /// the frozen `remaining` (`startDate = date − (totalDuration − remaining)`).
    ///
    /// Because both the carried-over `startDate` and `date` are shared across devices, the
    /// recomputed anchor is identical on both. Only acts while paused; does not replay start
    /// feedback (this is a remote-driven resume).
    func resume(at date: Date)

    /// Starts the timer anchored to the supplied absolute `date`, which may lie in the past.
    ///
    /// Used when a mirror joins late (e.g. a StartTimerMessage delivered after its
    /// `scheduledStartTime`): anchoring to the leader's start date makes the mirror show the
    /// same elapsed time instead of lagging by the delivery delay. Only acts while stopped;
    /// does not replay start feedback (this is a remote-driven start).
    func start(at date: Date)
}

// MARK: - Default Implementations

extension WorkoutTimer {
    /// Whether the workout timer has completed (total time has reached zero).
    var isCompleted: Bool {
        totalTimeRemaining <= 0
    }

    // Safe default so non-model conformers (e.g. test stubs) still compile; the concrete
    // EMOM/AMRAP models override this with a stored property set in `update()`.
    var didComplete: Bool { false }

    // Default forwarding so conformers that don't need canonical-date anchoring still compile.
    // The concrete EMOM/AMRAP models override these with the real shared-anchor math.
    func pause(at date: Date) { pause() }
    func resume(at date: Date) { start() }
    func start(at date: Date) { start() }
}
