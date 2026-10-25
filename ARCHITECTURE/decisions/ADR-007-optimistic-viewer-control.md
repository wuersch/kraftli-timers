# ADR-007: Optimistic viewer control with owner-wins reconciliation

**Status**: Accepted
**Date**: 2026-10-25
**Depends on**: [ADR-006](ADR-006-single-owner-timer-state.md)

## Context

Under ADR-006 one device owns a workout's `TimerState`; the other renders it. The viewer still
needs controls: the user may pause on the iPhone while the Watch owns the workout, count an AMRAP
round on whichever device is closer, or stop from either side.

The open question is what happens when the owner is **unreachable** at that moment (Bluetooth
drop, phone across the room, Watch app suspended). Two options were discussed:

- **A — disable viewer controls while disconnected.** Simple, conflict-free, but the device in
  your hand appears broken exactly when connectivity is worst.
- **B — apply locally right away, deliver later, owner wins on conflict.**

B was chosen. It is the same pattern multiplayer games (client-side prediction with an
authoritative server) and collaborative editors use: the local UI responds immediately, the
authority decides, and the client snaps to the authority's answer.

## Decision

### 1. Intents, not commands

A viewer action is an **intent**:

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

- Every intent carries the **tap time**. Because the clocks agree (ADR-006 assumptions), the owner
  applies the action at the moment the user acted, not when the message arrived, so delivery
  latency no longer shows up as drift. The time is clamped to `[lastTransitionAt, now]`, so a late
  or clock-skewed intent can't rewrite an earlier pause cycle or act in the future.
- Intents are sent over the fastest available channel (mirrored-session data, then `sendMessage`)
  and always also queued via `transferUserInfo`, so they survive a disconnect. The owner processes
  each `id` once and lists it in the snapshot's `handledIntentIDs` (applied *or* rejected), so
  redelivery is harmless.
- The owner's own taps go through the same reducer as intents against its current revision, so
  local and remote actions follow identical rules.

### 2. Optimistic prediction on the viewer

- The viewer keeps two things: the last **confirmed** snapshot from the owner and an ordered list of
  **pending** intents.
- What it renders is `confirmed` with `pending` applied on top, using the **same pure reducer** the
  owner uses. A pause therefore freezes the viewer's display instantly.
- A small "not yet confirmed" indicator is shown while intents are pending *and* the owner is
  unreachable (e.g. "Watch disconnected" on iPhone), so the user knows the other device hasn't heard.

### 3. Reconciliation (owner wins)

When the owner receives a batch of intents:

| Action | Owner does |
|--------|-----------|
| pause/resume, `baseRevision ≥ pauseStateRevision` | Apply in order (no conflict: the owner's paused/running state hasn't changed since the viewer's base) |
| pause/resume, `baseRevision < pauseStateRevision` | **Reject**: the owner paused or resumed meanwhile, and its state wins |
| `.incrementRound` | Apply (round counts commute) unless tapped during the countdown or after the workout ended |
| `.stop` | Apply unless already finished (stopping is never wrong to honor). If time had already run out, record the natural completion instead |

A pause/resume that *follows the sender's own* earlier pause/resume is not a conflict: if the
state's `pauseStateIntentID` (the intent that last changed the paused/running state) equals the
intent's `previousPauseIntentID`, it's applied. Queued intents can arrive in separate deliveries
(first `[pause]`, later `[pause, resume]`). Without this rule, applying the viewer's own pause would
make its own resume look like a conflict.

Conflicts are judged on `pauseStateRevision`, not on `revision`. Otherwise every round counted on
the owner would invalidate a viewer's pause. Whatever the batch does, `revision` is bumped once so
the new `handledIntentIDs` reach the viewer.

When the viewer receives a newer snapshot it drops every pending intent listed in
`handledIntentIDs` and re-renders. Because the viewer predicts with the same reducer, its
prediction already accounts for any conflict the owner will find. If a pause/resume was rejected, the display visibly snaps to
the owner's state. That is the accepted cost of B. A short neutral hint ("Synced with Watch" /
"Synced with iPhone") explains the jump. A rejection needs changes on both devices during the same
disconnect, so this is rare.

The viewer resends its whole pending list with every new intent, so intents created while
disconnected travel as **one ordered list**. Together with the chaining rule above, "pause, wait,
resume" on the viewer is either fully applied or fully rejected — never half — however the
transport splits the deliveries.

### 4. Owner unreachable for the rest of the workout

The viewer's prediction keeps running from absolute dates. When it reaches zero it shows completion
locally. The authoritative finish arrives through the owner's queued final snapshot /
`WorkoutSessionEndedMessage`. If the owner never reports (e.g. Watch battery died), the starting
device logs the workout from its predicted state when the time runs out. Data from the dead owner
(heart rate) is lost, which can't be avoided.

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| A — Disable viewer controls while the owner is unreachable | No conflicts, no rollback, least code | Controls appear broken when connectivity is worst, which is when they're most needed (phone out of reach, wrist available — or vice versa) |
| Viewer becomes owner when the owner is unreachable (failover) | Viewer stays fully in control | Two owners after reconnect → needs a merge protocol (the problem ADR-006 removes); the HK session/Health save can't migrate |
| Last-writer-wins by timestamp | Symmetric, simple rule | Lets a stale viewer action override what the owner (and the wearer) actually experienced; HK session state on the owner would have to be rewritten after the fact |
| **B — Optimistic intents, owner wins (chosen)** | Instant feedback on both devices; works offline; one authority; conflicts are rare and resolve deterministically | Occasional visible snap-back on conflict; pending-intent bookkeeping and a reducer shared by both devices |

## Consequences

### Positive
- Both devices respond immediately to every tap, connected or not.
- Pause/resume applied at tap time removes the latency-sized drift of today's iPhone-initiated
  pause path.
- AMRAP rounds counted on either device are never lost (queued delivery, commutative, deduped).

### Negative
- Rare snap-back after a conflicting pause/resume made on both devices while disconnected.
- The reducer must be identical on both devices: it lives in shared code and is covered by
  unit tests.

### Neutral
- Stop is honored from either side even when stale, matching the user's intent ("I'm done").

## Future Direction

- The same intent protocol works for future viewer controls (e.g. skip interval) without new
  arbitration rules.
