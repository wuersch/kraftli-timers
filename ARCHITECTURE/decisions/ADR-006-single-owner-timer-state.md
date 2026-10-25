# ADR-006: Single-owner timer state replicated as snapshots

**Status**: Accepted
**Date**: 2026-10-25
**Supersedes**: [ADR-003](ADR-003-cross-device-timer-anchoring.md),
[ADR-004](ADR-004-application-context-timer-command.md),
[ADR-005](ADR-005-mirrored-control-arbitration.md)

## Context

A mirrored workout currently runs as **two independent timers** (iPhone and Watch) kept in step
by **replicating events** — start, pause, resume, stop, increment-round — over two transports
(WatchConnectivity and HealthKit mirrored-session transitions). ADR-003, -004 and -005 each fixed
one race in that design, but on a real device pair it still never runs perfectly. The October 2026
sync review traced the remaining symptoms to the design itself, not to individual bugs:

- **No single clock decides.** Each device anchors start, pause and resume to *its own* `now()`.
  The start is offset by countdown wake-up jitter plus a 400 ms "GO" delay that the Watch's
  late-join/skip paths omit (a constant ~0.4 s Watch lead). The *initiating* device of a pause/resume
  keeps its local-clock anchor; only the receiver uses HealthKit's canonical date, so
  ADR-003's lockstep holds on one side only.
- **Arbitration diverges.** ADR-005's "HK is the sole channel while a session is active" is
  evaluated against *different* signals per device (iPhone: "I hold a mirrored session"; Watch:
  "my session is running"). Before mirroring connects and after every Bluetooth drop, iPhone
  pause/play is sent over WC and dropped by the Watch.
- **Events are not idempotent.** AMRAP rounds travel as best-effort `+1` messages that the receiver
  discards when it isn't running; lost or reordered events leave the devices permanently different.
- **Ownership is implicit.** `watchHandledWorkout` is set when `startWatchApp` *returns*, not when
  the Watch actually runs a session, so a failed Watch launch can silently drop the Health save.
  A failed launch is otherwise invisible: the iPhone runs alone without telling the user.

Every one of these is a symptom of *two writers* of timer state communicating through *events*.

## Decision

**Exactly one device owns a workout's timer state. The owner publishes the whole state as a
versioned snapshot; the other device is a viewer that renders from the latest snapshot.**

### 1. Ownership

| Situation | Owner | Viewer |
|-----------|-------|--------|
| Started on iPhone, Watch confirms within the handshake timeout | Watch | iPhone |
| Started on iPhone, no Watch paired / app not installed | iPhone | — |
| Started on iPhone, Watch launch fails or times out | iPhone | (late Watch yields, see §4) |
| Started on Watch | Watch | iPhone (if listening) |

The Watch is the preferred owner because it runs the primary `HKWorkoutSession` (heart rate,
calories, background runtime, crash recovery). Whoever owns the timer also owns the HealthKit
session and the Health save — so a workout is saved exactly once, by construction.

### 2. The state

```swift
struct TimerState: Codable, Equatable, Sendable {
    let workoutID: UUID          // today's correlationID; also the WorkoutLog.id
    let owner: DeviceRole        // .watch | .phone
    let revision: Int            // incremented by the owner on every change
    let config: TimerConfig      // kind, totalDuration, intervalCount, exerciseName
    var startDate: Date          // t = 0 of the workout (after the countdown)
    var pausedAt: Date?          // non-nil while paused
    var accumulatedPause: TimeInterval
    var lastTransitionAt: Date   // last start/pause/resume; intent times are clamped to ≥ this
    var pauseStateRevision: Int  // revision of the last paused/running change (ADR-007 conflicts)
    var roundCount: Int          // AMRAP rounds (absolute, not increments)
    var finish: Finish?          // .completed(at:) | .stopped(at:)
    var handledIntentIDs: [UUID] // processed (applied or rejected), bounded; see ADR-007
}

// Pure, identical on both devices:
elapsed(at now) = clamp((pausedAt ?? finish?.date ?? now) − startDate − accumulatedPause,
                        0 … totalDuration)
```

- The countdown is implicit: `now < startDate` means "counting down". The owner picks
  `startDate = now + 3 s` once; both devices count down to the same absolute instant and start
  from it — no per-device wake-up, no GO-delay offset.
- Everything the UI shows (remaining time, interval, reps, progress, completion) is derived from
  `TimerState` + the local clock. The existing display/feedback math in the timer models stays;
  their `start/pause/resume` entry points are replaced by `apply(_ state: TimerState)`.
- Interval/warning/completion **sounds and haptics** fire on locally observed transitions, as
  today. Applying a snapshot that jumps (late join, conflict rollback) pre-seeds the trackers, as
  `start(at:)` already does, so nothing replays.

### 3. Replication

- **Receivers apply a snapshot only if `workoutID` matches and `revision` is higher** than the one
  they hold. Duplicates, reordering and redelivery are therefore harmless, and resending the latest
  snapshot is always safe.
- The owner publishes each new snapshot on **every available transport**:
  1. HealthKit `sendToRemoteWorkoutSession(data:)` over the mirrored session (primary path while
     connected),
  2. WatchConnectivity `updateApplicationContext` (latest-wins, persisted — covers cold launches
     and app relaunches),
  3. WatchConnectivity `sendMessage` when reachable (low latency).
  Redundancy is cheap because application is idempotent, and it guards against the reported case
  of `sendToRemoteWorkoutSession` silently hanging for the rest of a workout.
- **On reconnect** (mirroring restarted, reachability regained) the owner republishes its latest
  snapshot. The viewer never needs to ask.
- The final snapshot (with `finish`) plus the existing `WorkoutSessionEndedMessage` (Health UUID,
  heart rate, calories) also go through `transferUserInfo`, the only queued, guaranteed channel.

HealthKit's own pause/resume becomes a **consequence** of the state, not a control channel: the
owner calls `session.pause()/resume()` when `pausedAt` changes. Neither device reacts to
mirrored-session transitions for timer logic anymore, so there is nothing left to arbitrate.

### 4. Start handshake (iPhone-started)

1. iPhone generates `workoutID`. If `WCSession.isPaired && isWatchAppInstalled` is false → iPhone
   becomes owner immediately (no waiting).
2. Otherwise it publishes a `StartRequest(workoutID, config)` (context + message) and calls
   `startWatchApp(toHandle:)`, showing **"Starting on Watch…"**.
3. The Watch starts the HK session, waits for `.running`, starts mirroring, then publishes revision 1
   with `startDate = now + 3 s`. The iPhone shows the countdown when that snapshot arrives.
4. If `startWatchApp` throws, or no snapshot arrives within the **handshake timeout (5 s)**, the
   iPhone becomes owner, publishes its own revision-1 snapshot (`owner: .phone`) as the application
   context, and shows a short "Watch not available — running on iPhone" note.
5. A Watch that starts late and sees `owner: .phone` for that `workoutID` **yields**: it ends its HK
   session without saving and becomes a viewer. It records no heart rate and is kept on screen by
   the existing `WKExtendedRuntimeSession` fallback. The iPhone is the arbiter for iPhone-started
   workouts, so a crossed handshake always resolves to one owner. Ownership never moves after the
   handshake.

### 5. Viewer control

The viewer never mutates authoritative state. Pause, resume, round and stop on the viewer become
**intents** sent to the owner; the viewer predicts the result locally for responsiveness. The
protocol and the conflict rule (owner wins) are specified in
[ADR-007](ADR-007-optimistic-viewer-control.md).

### Assumptions

- iPhone and Watch wall clocks agree to within tens of milliseconds (the Watch takes its time from
  the paired iPhone). Rendering from absolute dates relies on this; a measured clock offset can be
  added later without changing the model.
- `sendToRemoteWorkoutSession` requires the session to be prepared/running and mirroring started;
  the owner publishes over WC only until then.

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep event replication, apply the review's point fixes | Smallest diffs; no protocol change | Treats symptoms; every new control path re-opens the same race class; three ADRs already spent on it |
| iPhone always owns, Watch renders | iPhone is where the user starts most workouts; no Watch launch latency before countdown | The iPhone has no HK primary session in the common case → Watch would still own HR/Health save, so two "owners" again; iPhone app is often suspended/killed while locked, the Watch is not |
| Owner streams display ticks (e.g. remaining seconds every 1 s) | Trivial viewer | Chatty; jittery display; breaks on any gap; doesn't survive disconnects |
| Shared CRDT state, both devices write | No single point of authority | Massive overkill for one user and two devices; pause/resume aren't naturally mergeable |
| **Single owner + versioned snapshots (chosen)** | One clock decides; idempotent, order-insensitive replication; disconnects degrade gracefully; ownership — and the Health save — explicit | Start waits for the Watch (seconds on cold launch); viewer actions need the intent protocol of ADR-007; rewrite of the sync layer |

## Consequences

### Positive
- The display offset between devices is bounded by clock skew (ms), on every path: start, late
  join, skip, pause/resume from either side, reconnect.
- Removes the HK-vs-WC arbitration (ADR-005), the per-channel staleness/dedup rules (ADR-004) and
  the canonical-date reconcile (ADR-003). Most of `WatchMessageCoordinator`'s dedup state goes away.
- A failed Watch launch becomes an explicit, visible iPhone-only workout instead of a silent
  half-working one, and the Health save always matches the owner.
- Every behavior is a pure function of `(TimerState, now)` plus a reducer → unit-testable without
  devices.

### Negative
- An iPhone-started workout's countdown begins only after the Watch confirms (≈ instant when the
  Watch app is warm, a few seconds on cold launch). "Starting on Watch…" makes the wait visible.
  This changes the *Synchronized Countdown* behavior in `SPEC/scope.md`, which must be updated.
- New shared types must be added to the Watch target's membership exceptions (manual Xcode step).
- Existing sync tests (coordinator dedup, reconcile, stop routing) are largely replaced.

### Neutral
- `TimerControlMessage`, `StopTimerMessage`, `StartTimerMessage.displayOnly`, `watchHandledWorkout`
  and both reconcile functions are retired. `WorkoutSessionEndedMessage` and the correlation-ID
  based `WorkoutLog` linking stay.
- SwiftData logging rules are unchanged: the device that started the workout writes the
  `WorkoutLog`; the owner writes the Health workout.

## Future Direction

- iOS 26 can run an `HKWorkoutSession` on iPhone. A phone-owned workout could then record heart
  rate from AirPods/BLE straps and save a richer Health workout, without changing this model.
- Showing a Watch-started workout live on the iPhone becomes a pure viewer feature. It is not in
  scope today and would need promotion from the backlog.
- If clock skew ever proves visible, the owner can include its send time and the viewer can
  estimate an offset (NTP-style) from round trips.
