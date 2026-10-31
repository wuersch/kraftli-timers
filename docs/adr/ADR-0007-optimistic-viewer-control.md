# ADR-0007: Viewer controls send optimistic intents; the owner wins on conflict

- **Status:** implemented
- **Date:** 2026-10-25 (amended 2026-10-31)
- **Deciders:** Michael Würsch

## Context and Problem Statement

Under [ADR-0006](ADR-0006-single-owner-timer-state.md) one device owns a workout's `TimerState`
and the other renders it. The viewer still needs controls. The user may pause on the iPhone while
the Watch owns the workout, count an AMRAP round on whichever device is closer, or stop from either
side.

What should a viewer's controls do, especially when the owner is **unreachable** at that moment
(Bluetooth drop, phone across the room, Watch app suspended)?

## Decision Drivers

- Controls on the device in hand must respond immediately, connected or not
- A single authority for the timer state (no second writer, no merge protocol)
- AMRAP rounds must never be lost
- Deterministic, rare conflicts

## Considered Options

- A: disable viewer controls while the owner is unreachable
- Failover: the viewer becomes the owner while the owner is unreachable
- Last-writer-wins by timestamp
- B: optimistic intents, owner wins

## Decision Outcome

Chosen option: **B, optimistic intents with the owner winning conflicts**. It is the pattern of
client-side prediction against an authoritative server: instant feedback, one authority, and
deterministic resolution.

### 1. Intents, not commands

```swift
struct TimerIntent: Codable, Equatable, Sendable {
    let id: UUID              // dedup key
    let workoutID: UUID
    let baseRevision: Int     // last *confirmed* owner revision the viewer had
    let action: Action        // .pause | .resume | .incrementRound | .stop
    let at: Date              // when the user acted
    let previousPauseIntentID: UUID?  // the sender's own unconfirmed pause/resume this follows
}
```

- **Every intent carries the tap time.** The owner applies the action at the moment the user acted,
  clamped to `[lastTransitionAt, now]`, so delivery latency doesn't show up as drift.
- **Delivery:** intents are sent over the fastest channel (mirrored-session data, then `sendMessage`)
  and always also queued via `transferUserInfo`. The owner processes each `id` once and lists it in
  `handledIntentIDs`, whether applied or rejected.
- **The owner's own taps** go through the same reducer.

### 2. Optimistic prediction on the viewer

- The viewer keeps the last **confirmed** snapshot and an ordered list of **pending** intents.
- It renders the confirmed snapshot with the pending intents applied on top, using the **same pure
  reducer** the owner uses.
- A "not yet confirmed" indicator is shown **whenever intents are pending**. The original version
  showed it only while the owner was also unreachable; see More Information.

### 3. Reconciliation (owner wins)

| Action | Owner does |
|--------|-----------|
| pause/resume, `baseRevision ≥ pauseStateRevision` | Apply in order |
| pause/resume, `baseRevision < pauseStateRevision` | **Reject**: the owner paused or resumed meanwhile, and its state wins |
| `.incrementRound` | Apply (round counts commute), unless tapped during the countdown or after the end |
| `.stop` | Apply unless already finished. If the time had already run out, record the natural completion instead |

- **Chained pause/resume is not a conflict.** A pause/resume that follows the sender's own earlier
  pause/resume (`previousPauseIntentID == pauseStateIntentID`) is applied.
- **Conflicts are judged on `pauseStateRevision`, not on `revision`.** Otherwise every round
  counted on the owner would invalidate a pause from the viewer.
- **The viewer resends its whole pending list with every new intent.** So a "pause, wait, resume"
  made offline is either fully applied or fully rejected.
- **When the viewer receives a newer snapshot,** it drops every pending intent listed in
  `handledIntentIDs` and re-renders.
- **If a pause/resume was rejected,** the display snaps to the owner's state, and a short neutral hint
  explains the jump: "Synced with Watch" on the iPhone, "Synced with iPhone" on the Watch.

### 4. Owner unreachable for the rest of the workout

- The viewer's prediction keeps running from absolute dates and shows completion locally.
- The authoritative finish arrives later through the owner's queued final snapshot.
- If the owner never reports (e.g. the Watch battery died), the starting device logs the workout from
  its predicted state. The dead owner's data, such as heart rate, is lost.

### Consequences

- Good, because both devices respond immediately to every tap, connected or not.
- Good, because applying pause/resume at tap time removes latency-sized drift.
- Good, because AMRAP rounds counted on either device are never lost: they are queued, commutative and deduplicated.
- Bad, because a rare visible snap-back happens after conflicting pause/resume on both devices
  during the same disconnect.
- Bad, because the reducer must be identical on both devices, so it lives in shared code, must be
  covered by unit tests, and requires pending-intent bookkeeping.
- Neutral: stop is honored from either side even when stale ("I'm done").

### Confirmation

`TimerStateReducer` and `TimerSessionController` unit tests cover the reconciliation table,
chained intents and the handling of redelivered intents.

## Pros and Cons of the Options

### A: disable viewer controls while unreachable

- Good, because there are no conflicts, no rollback, and the least code.
- Bad, because controls appear broken when connectivity is worst, which is when they're most needed.

### Failover: the viewer becomes the owner

- Good, because the viewer stays fully in control.
- Bad, because there would be two owners after reconnect, needing the merge protocol ADR-0006 removes.
- Bad, because the HealthKit session and Health save can't migrate between devices.

### Last-writer-wins by timestamp

- Good, because it is a symmetric, simple rule.
- Bad, because a stale viewer action could override what the owner and the wearer actually
  experienced, and the owner's HealthKit session state would have to be rewritten after the fact.

### B: optimistic intents, owner wins

- Good, because feedback is instant, it works offline, there is one authority, and conflicts are
  deterministic.
- Bad, because of occasional snap-back, plus the bookkeeping and a reducer shared by both devices.

## More Information

- **Amendment 2026-10-31:** the pending indicator (an iPhone Watch-slash icon next to the total time)
  shows whenever intents are pending. This was confirmed as intended.
- **Known gap:** the Watch doesn't show "Synced with iPhone" yet; only the iPhone shows its notice.
  It remains part of this decision and is a fix candidate.
- Requirements: [UC-0003](../use-cases/UC-0003-run-an-iphone-started-workout-with-the-watch.md).
- Future direction: the same intent protocol can serve future viewer controls (e.g. skip interval)
  without new arbitration rules.
