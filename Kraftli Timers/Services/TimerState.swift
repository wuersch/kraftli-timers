//
//  TimerState.swift
//  Kraftli Timers
//
//  The authoritative, replicated state of one workout timer (ADR-006).
//  Shared by the iPhone and Watch targets.
//
//  ## Why a value instead of events
//  One device (the *owner*) holds the real `TimerState` and publishes every new
//  version as a snapshot. The other device (the *viewer*) renders whatever the
//  newest snapshot says. Because a snapshot describes the whole timer — not "what
//  just happened" — duplicates, reordering and redelivery are harmless: a receiver
//  keeps the snapshot with the highest `revision` and drops the rest.
//
//  Everything shown on screen is derived from the state plus the local clock
//  (`elapsed(at:)`), so both devices compute the same remaining time from the same
//  absolute dates instead of each running its own stopwatch.
//
//  ## Concurrency
//  The app targets default to MainActor isolation. These types are `nonisolated`
//  so they can be encoded/decoded inside HealthKit and WatchConnectivity delegate
//  callbacks, which arrive on background queues.
//

import Foundation

// MARK: - DeviceRole

/// Which device runs the authoritative timer for a workout.
nonisolated enum DeviceRole: String, Codable, Sendable {
    case watch
    case phone

    /// The device this code is running on.
    static var current: DeviceRole {
        #if os(watchOS)
        .watch
        #else
        .phone
        #endif
    }
}

// MARK: - TimerConfig

/// The immutable setup of a workout, fixed when it starts.
nonisolated struct TimerConfig: Codable, Equatable, Sendable {
    /// Raw `TimerKind` value. Stored raw (like `StartTimerMessage`) so this type
    /// stays independent of the MainActor-isolated `TimerKind` conformances.
    let timerKindRaw: String
    let totalDuration: TimeInterval
    /// Number of EMOM intervals (reps); nil for AMRAP.
    let intervalCount: Int?
    let exerciseName: String
}

// MARK: - TimerState

/// The complete state of one workout timer, owned by exactly one device.
///
/// Only the owner changes it, and only through `TimerStateReducer`, which bumps
/// `revision` on every change.
nonisolated struct TimerState: Codable, Equatable, Sendable {
    /// How a workout ended.
    enum Finish: Codable, Equatable, Sendable {
        /// Ran to zero. `at` is the instant the remaining time reached zero.
        case completed(at: Date)
        /// Ended early by the user.
        case stopped(at: Date)

        var date: Date {
            switch self {
            case .completed(let date), .stopped(let date): date
            }
        }
    }

    /// Length of the shared 3-2-1 countdown before `startDate`.
    static let countdownDuration: TimeInterval = 3

    /// How many processed intent IDs a snapshot remembers (oldest dropped first).
    static let handledIntentIDLimit = 64

    /// Identifies the workout; also used as the iPhone's `WorkoutLog.id`.
    let workoutID: UUID
    let owner: DeviceRole
    let config: TimerConfig

    /// Incremented by the owner on every change. Receivers keep the highest.
    var revision: Int

    /// Workout time zero (the end of the countdown). Before it, the timer counts down.
    var startDate: Date
    /// Non-nil while paused: the instant the pause took effect.
    var pausedAt: Date?
    /// Total time spent paused in completed pause/resume cycles.
    var accumulatedPause: TimeInterval
    /// When the timer last started, paused or resumed. Intent times are clamped
    /// to not lie before it, so a late or skewed intent can't rewrite history.
    var lastTransitionAt: Date
    /// The revision at which the paused/running state last changed. A viewer's
    /// pause/resume conflicts only if this moved past its base revision — round
    /// taps on the owner don't count as conflicts (ADR-007).
    var pauseStateRevision: Int
    /// The intent that last changed the paused/running state, if any. A viewer's
    /// follow-up pause/resume built on that same intent is not a conflict, even if
    /// it arrives separately (ADR-007).
    var pauseStateIntentID: UUID?

    /// AMRAP rounds completed, as an absolute count.
    var roundCount: Int
    /// Set once the workout has ended.
    var finish: Finish?

    /// Intents the owner has processed — applied *or* rejected — so the viewer
    /// can drop exactly those from its pending list.
    var handledIntentIDs: [UUID]

    /// Creates revision 1 of a new workout, whose countdown starts at `now`.
    init(workoutID: UUID, owner: DeviceRole, config: TimerConfig, now: Date) {
        self.init(
            workoutID: workoutID,
            owner: owner,
            config: config,
            startDate: now.addingTimeInterval(Self.countdownDuration)
        )
    }

    /// Creates revision 1 of a new workout whose clock starts at `startDate`
    /// (which may lie in the past, e.g. when joining a running workout).
    init(workoutID: UUID, owner: DeviceRole, config: TimerConfig, startDate: Date) {
        self.workoutID = workoutID
        self.owner = owner
        self.config = config
        self.revision = 1
        self.startDate = startDate
        self.pausedAt = nil
        self.accumulatedPause = 0
        self.lastTransitionAt = startDate
        self.pauseStateRevision = 1
        self.pauseStateIntentID = nil
        self.roundCount = 0
        self.finish = nil
        self.handledIntentIDs = []
    }

    // MARK: - Derived values (identical on every device)

    /// Workout time elapsed at `now`, excluding pauses, clamped to `0...totalDuration`.
    func elapsed(at now: Date) -> TimeInterval {
        // A paused timer is frozen at its pause; a finished one at its end.
        let reference = pausedAt ?? finish?.date ?? now
        let raw = reference.timeIntervalSince(startDate) - accumulatedPause
        return min(max(raw, 0), config.totalDuration)
    }

    func remaining(at now: Date) -> TimeInterval {
        config.totalDuration - elapsed(at: now)
    }

    var isPaused: Bool {
        pausedAt != nil
    }

    /// True during the shared 3-2-1 countdown.
    func isCountingDown(at now: Date) -> Bool {
        finish == nil && now < startDate
    }

    /// True once the workout ended, either explicitly or by reaching zero.
    func isFinished(at now: Date) -> Bool {
        finish != nil || elapsed(at: now) >= config.totalDuration
    }

    /// True while the workout clock is advancing.
    func isRunning(at now: Date) -> Bool {
        !isPaused && !isCountingDown(at: now) && !isFinished(at: now)
    }
}

// MARK: - TimerIntent

/// A request to change a workout's state, made on either device and applied
/// by the owner (ADR-007).
///
/// Carries the time the user acted (`at`), so the owner applies a pause at the
/// moment of the tap rather than when the message happened to arrive.
nonisolated struct TimerIntent: Codable, Equatable, Sendable, Identifiable {
    enum Action: String, Codable, Sendable {
        case pause
        case resume
        case incrementRound
        case stop
    }

    /// Dedup key: the owner processes each intent at most once.
    let id: UUID
    let workoutID: UUID
    /// The last owner revision the sender had confirmed when it acted.
    let baseRevision: Int
    let action: Action
    /// When the user acted.
    let at: Date
    /// For pause/resume: the sender's own earlier pause/resume this one follows, if it
    /// wasn't confirmed yet. Lets the owner tell "the viewer's own chain" apart from a
    /// real conflict when queued intents arrive in separate deliveries.
    let previousPauseIntentID: UUID?

    init(
        id: UUID = UUID(),
        workoutID: UUID,
        baseRevision: Int,
        action: Action,
        at: Date,
        previousPauseIntentID: UUID? = nil
    ) {
        self.id = id
        self.workoutID = workoutID
        self.baseRevision = baseRevision
        self.action = action
        self.at = at
        self.previousPauseIntentID = previousPauseIntentID
    }
}
