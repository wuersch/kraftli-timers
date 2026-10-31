# ADR-0006: One device owns a workout's timer state and replicates it as versioned snapshots

- **Status:** implemented
- **Date:** 2026-10-25 (amended 2026-10-31)
- **Deciders:** Michael Würsch

## Context and Problem Statement

A mirrored workout ran as **two independent timers**, one on the iPhone and one on the Watch. They
were kept in step by **replicating events** (start, pause, resume, stop, increment-round) over two
transports: WatchConnectivity and HealthKit mirrored-session transitions.
[ADR-0003](ADR-0003-cross-device-timer-anchoring.md),
[ADR-0004](ADR-0004-application-context-timer-command.md) and
[ADR-0005](ADR-0005-mirrored-control-arbitration.md) each fixed one race, yet on a real device
pair it still never ran perfectly. The October 2026 sync review traced the remaining symptoms to
the design itself:

- **No single clock decides.** Each device anchored start, pause and resume to its own `now()`.
  Countdown wake-up jitter plus a 400 ms "GO" delay, which the Watch's late-join path omitted, gave
  the Watch a constant ~0.4 s lead. The device that initiated a pause or resume kept its local-clock
  anchor, so ADR-0003's lockstep held on one side only.
- **Arbitration diverges.** ADR-0005's rule was evaluated against different signals per device,
  so iPhone pause/play was dropped before mirroring connected and after every Bluetooth drop.
- **Events are not idempotent.** AMRAP rounds travelled as best-effort `+1` messages. Lost or
  reordered events left the devices permanently different.
- **Ownership is implicit.** `watchHandledWorkout` was set when `startWatchApp` *returned*, not
  when the Watch actually ran a session. A failed launch could silently drop the Health save, and
  the iPhone ran alone without telling the user.

Every one of these is a symptom of two writers of timer state communicating through events. How
should two devices run one workout so that they always agree?

## Decision Drivers

- One clock decides; the display offset between devices bounded by clock skew
- Replication that is idempotent and doesn't depend on message order, and tolerates disconnects
- Explicit ownership of the workout, and therefore of the Health save
- A failed Watch launch must be visible, not silent
- Logic testable without devices

## Considered Options

- Keep event replication and apply the review's point fixes
- The iPhone always owns, the Watch renders
- The owner streams display ticks
- Shared CRDT state, both devices write
- Single owner + versioned snapshots

## Decision Outcome

Chosen option: **Single owner + versioned snapshots**. One clock decides, replication is
idempotent and order-insensitive, disconnects degrade gracefully, and ownership (and with it the
Health save) is explicit.

### 1. Ownership

| Situation | Owner | Viewer |
|-----------|-------|--------|
| Started on iPhone, Watch confirms within the handshake timeout | Watch | iPhone |
| Started on iPhone, no Watch paired / app not installed | iPhone | — |
| Started on iPhone, Watch launch fails or times out | iPhone | (a late Watch yields, see §4) |
| Started on Watch | Watch | iPhone (if listening; today it isn't) |

The Watch is the preferred owner because it runs the primary `HKWorkoutSession` (heart rate,
calories, background runtime, crash recovery). Whoever owns the timer also owns the HealthKit
session and the Health save, so a workout is saved exactly once by construction.

### 2. The state

```swift
struct TimerState: Codable, Equatable, Sendable {
    let workoutID: UUID          // also the WorkoutLog.id
    let owner: DeviceRole        // .watch | .phone
    let revision: Int            // incremented by the owner on every change
    let config: TimerConfig      // kind, totalDuration, intervalCount, exerciseName
    var startDate: Date          // t = 0 of the workout (after the countdown)
    var pausedAt: Date?          // non-nil while paused
    var accumulatedPause: TimeInterval
    var lastTransitionAt: Date   // last start/pause/resume; intent times are clamped to ≥ this
    var pauseStateRevision: Int  // revision of the last paused/running change (ADR-0007 conflicts)
    var roundCount: Int          // AMRAP rounds (absolute, not increments)
    var finish: Finish?          // .completed(at:) | .stopped(at:)
    var handledIntentIDs: [UUID] // processed (applied or rejected), bounded; see ADR-0007
}

// Pure, identical on both devices:
elapsed(at now) = clamp((pausedAt ?? finish?.date ?? now) − startDate − accumulatedPause,
                        0 … totalDuration)
```

- **The countdown is implicit:** `now < startDate` means "counting down". The owner sets
  `startDate = now + 3 s` once, and both devices count down to the same instant.
- **Everything shown is derived** from `TimerState` and the local clock: remaining time, interval,
  reps, progress and completion. Timer models expose `apply(_ state: TimerState)` and only render.
- **Feedback fires on locally observed transitions.** Interval and completion sounds play only
  when a device sees the change happen. Applying a snapshot that jumps ahead (late join, conflict
  rollback) pre-seeds the trackers, so nothing replays.
- **Only `TimerStateReducer` changes the state.** It is a pure function, shared by both targets.

### 3. Replication

- **Receivers apply a snapshot only if** its `workoutID` matches and its `revision` is higher than
  the one they hold. Duplicates, reordering and redelivery are harmless, and resending is always safe.
- **The owner publishes on every available transport** (`CompositeTimerSyncTransport`):
  1. HealthKit `sendToRemoteWorkoutSession(data:)` over the mirrored session, while mirrored.
  2. WatchConnectivity `updateApplicationContext`: latest wins and is persisted, which covers cold launches.
  3. WatchConnectivity `sendMessage` when reachable, for low latency.

  The redundancy is cheap because applying a snapshot is idempotent. It also guards against
  `sendToRemoteWorkoutSession` silently hanging for the rest of a workout.
- **On reconnect** the owner republishes its latest snapshot.
- **The final snapshot** (with `finish`) and the `WorkoutSessionEndedMessage` also go through
  `transferUserInfo`, the only queued, guaranteed channel.
- **HealthKit's pause/resume is a consequence** of the state, not a control channel: the owner pauses
  its session when `pausedAt` changes. Mirrored-session transitions don't drive timer logic.

### 4. Start handshake (iPhone-started)

1. The iPhone generates the `workoutID`. If no Watch is paired, the app isn't installed, or the
   connection isn't activated yet, the iPhone becomes the owner immediately.
2. Otherwise it publishes a `StartRequest(workoutID, config)` and calls `startWatchApp(toHandle:)`,
   showing **"Starting on Watch…"**.
3. The Watch starts its HealthKit session. **As soon as the session has started, it takes ownership**:
   revision 1, with `startDate = now + 3 s`. Mirroring starts in parallel and is not awaited;
   snapshots go over WatchConnectivity until the mirrored channel is up. A start request older than
   10 s is ignored. If nobody becomes the owner within 10 s, a watchdog closes the Watch's
   "Starting…" screen.
4. If `startWatchApp` throws, or no snapshot arrives within the **handshake timeout (5 s)**, the
   iPhone becomes the owner. It publishes its own revision-1 snapshot (`owner: .phone`) and shows
   "Watch not available — running on iPhone".
5. **A late Watch yields.** If it sees `owner: .phone` for that `workoutID`, it discards its
   HealthKit session without saving and becomes a viewer. It records no heart rate and is kept
   running by a dedicated `WKExtendedRuntimeSession` keep-alive. For iPhone-started workouts the
   iPhone's snapshot wins whatever the revision, so a crossed handshake always ends with one owner.
   Ownership never moves after the handshake.

### 5. Viewer control

The viewer never changes authoritative state. Its pause, resume, round and stop become
**intents** sent to the owner, predicted locally for responsiveness. The protocol and the conflict
rule (owner wins) are in [ADR-0007](ADR-0007-optimistic-viewer-control.md).

### Assumptions

- The iPhone and Watch wall clocks agree within tens of milliseconds, because the Watch takes its
  time from the paired iPhone. A measured clock offset could be added later without changing the model.
- `sendToRemoteWorkoutSession` requires a prepared or running session with mirroring started. Until
  then the owner publishes over WatchConnectivity only.

### Consequences

- Good, because the display offset between devices is bounded by clock skew (milliseconds) on every
  path: start, late join, pause/resume from either side, and reconnect.
- Good, because it removes ADR-0005's arbitration, ADR-0004's per-channel staleness and dedup rules,
  and ADR-0003's canonical-date reconcile.
- Good, because a failed Watch launch becomes an explicit, visible iPhone-only workout, and the
  Health save always matches the owner.
- Good, because every behavior is a pure function of `(TimerState, now)` plus a reducer, which is
  unit-testable without devices.
- Bad, because an iPhone-started workout's countdown begins only after the Watch confirms. That is
  almost instant when the Watch app is warm, and a few seconds on cold launch.
- Bad, because new shared types must be added to the Watch target's membership exceptions
  (a manual Xcode step).
- Bad, because the sync layer was rewritten and most existing sync tests were replaced.
- Neutral: `TimerControlMessage`, `StopTimerMessage`, `StartTimerMessage.displayOnly`,
  `watchHandledWorkout` and both reconcile functions are retired. `WorkoutSessionEndedMessage` and
  the workout-ID linking stay.
- Neutral: the device that *started* the workout writes the `WorkoutLog`; the owner writes the
  Health workout.

## Pros and Cons of the Options

### Keep event replication with point fixes

- Good, because the diffs are smallest and there is no protocol change.
- Bad, because it treats symptoms. Every new control path re-opens the same class of race, and
  three ADRs were already spent on it.

### The iPhone always owns

- Good, because most workouts start there, and there is no Watch launch latency before the countdown.
- Bad, because the Watch would still own heart rate and the Health save, so there would be two
  "owners" again.
- Bad, because the iPhone app is often suspended while locked; the Watch app isn't.

### The owner streams display ticks

- Good, because the viewer becomes trivial.
- Bad, because it is chatty, makes the display jitter, breaks on any gap, and doesn't survive disconnects.

### Shared CRDT state, both devices write

- Good, because there is no single point of authority.
- Bad, because it is massive overkill for one user and two devices, and pause/resume don't merge naturally.

### Single owner + versioned snapshots

- Good, because one clock decides, replication is idempotent, and ownership is explicit.
- Bad, because the start waits for the Watch, viewer actions need ADR-0007's intent protocol, and
  the sync layer had to be rewritten.

## More Information

- Supersedes ADR-0003, ADR-0004 and ADR-0005. Amends ADR-0002 (who saves to Health).
- **Amendment 2026-10-31**, documenting the implementation (v1.6.x):
  - §4.3: the Watch takes ownership once its session has started and doesn't wait for mirroring
    (originally: wait for `.running`, start mirroring, then publish). This adds the 10 s
    stale-request and watchdog rules.
  - §4.5: a yielded Watch uses a dedicated keep-alive instead of the general extended-runtime fallback.
- Implementation plan and history: [docs/plans/watch-owned-timer-state.md](../plans/watch-owned-timer-state.md).
- Requirements: [UC-0003](../use-cases/UC-0003-run-an-iphone-started-workout-with-the-watch.md).
- Future direction:
  - Show a Watch-started workout live on the iPhone. This becomes a pure viewer feature, but is a
    backlog item and needs promotion first.
  - Run an iOS 26 `HKWorkoutSession` on iPhone-owned workouts.
  - Estimate the clock offset NTP-style if skew ever becomes visible.
