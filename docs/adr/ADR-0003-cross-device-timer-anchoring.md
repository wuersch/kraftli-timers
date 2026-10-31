# ADR-0003: Anchor cross-device pause/resume on HealthKit's canonical transition date

- **Status:** superseded by ADR-0006
- **Date:** 2026-05-26
- **Deciders:** Michael Würsch

## Context and Problem Statement

A mirrored workout timer ran as **two independent model instances**, one on the iPhone and one on
the Watch. A running timer was anchored to an absolute `startDate` and displayed
`remaining = totalDuration − (now − startDate)`. Synced device clocks and the shared
`scheduledStartTime` handshake (`StartTimerMessage`) kept the running phase aligned.

Pause/resume broke this alignment. On resume, each device recomputed its anchor from its own clock
at the moment it processed the event (`TimerCoordinator.start(pausedTime:)`:
`startDate = now − (totalDuration − pausedTime)`). On pause, each device captured its own elapsed
time. Pause/resume events reach the other device with latency, so the two sides anchored to
slightly different points. When control alternated between devices (pause on the Watch, resume on
the iPhone), the per-cycle error was the sum of both latencies and always in the same direction. Repeated
pause/resume made the two displayed times drift further apart, and nothing re-synchronized them
after the initial handshake.

How can both devices compute an identical anchor after every pause/resume cycle?

## Decision Drivers

- Remove the cause of the drift instead of masking it
- Keep the change small and avoid changing the message protocol
- Don't depend on WatchConnectivity's best-effort ordering, which is the failure mode here

## Considered Options

- Broadcast the absolute anchor over WCSession `TimerControlMessage`
- Periodic re-sync ticks (broadcast the current `remaining` every N seconds)
- Anchor off HealthKit's canonical transition `date`

## Decision Outcome

Chosen option: **Anchor off HealthKit's canonical transition `date`**. It removes the cause of the
drift with a small diff, and the shared timestamp already reaches both devices reliably through
HealthKit.

- `HKWorkoutSessionDelegate.workoutSession(_:didChangeTo:from:date:)` delivers the same `date` on
  both sides (it used to be discarded). `MirroredWorkoutObserver` (iOS) and `WorkoutSessionManager`
  (Watch) expose it as `lastTransitionDate`.
- The timer models gained `pause(at:)` / `resume(at:)`:
  - **Pause:** freeze `remaining = totalDuration − (date − startDate)`.
  - **Resume:** re-anchor `startDate = date − (totalDuration − remaining)`.
- `TimerCoordinator` gained:
  - `start(startDate:)`, which adopts an anchor verbatim instead of recomputing it.
  - An injectable `now: () -> Date` clock seam.
- The reconcile sites (`reconcileMirroredState` on iOS, `reconcileSessionState` on the Watch) call
  `pause(at:)` / `resume(at:)` with `lastTransitionDate`.
- **Scope: the HealthKit-mirroring path only.** The WCSession `TimerControlMessage` fallback (used
  when no HealthKit session exists) is unchanged.

### Consequences

- Good, because repeated, alternating pause/resume on the Watch and iPhone no longer drifts on the
  HealthKit path. The remaining drift is bounded by the small, constant initial start skew.
- Good, because the injected `now` clock makes the timing core deterministically testable.
- Good, because there are no changes to the message protocol, sync services or control publishers.
- Bad, because the WCSession fallback (no active HealthKit session) still re-anchors per device and can
  drift. This was accepted as a known limitation on a rare path.
- Bad, because a remote-driven resume goes through `resume(at:)`, which deliberately doesn't replay
  start feedback. That splits its behavior from the local resume path (`startAndScheduleHintHide`)
  in a way that is easy to miss.
- Neutral: `resume(at:)` preserves EMOM interval and warning state, so resuming never replays sounds.
  The reconcile sites keep their `isRunning` guards, so a redundant session pause/resume doesn't
  bounce the HealthKit session.

## Pros and Cons of the Options

### Broadcast the absolute anchor over WCSession `TimerControlMessage`

- Good, because it covers the no-HealthKit fallback too, and every message corrects the state on its own.
- Bad, because it is a larger diff: the message protocol, both sync services, control publishers,
  callbacks, and an ordering/staleness guard.
- Bad, because WCSession ordering is best-effort and unreliable, which is the exact failure mode here.

### Periodic re-sync ticks

- Good, because it corrects drift from any source.
- Bad, because it sends constant traffic and makes the display jitter during reconciliation.
- Bad, because it hides the cause rather than fixing it.

### Anchor off HealthKit's canonical transition `date`

- Good, because it fixes the cause, and the shared timestamp already arrives reliably on both devices.
- Good, because the diff is small and there are no wire changes.
- Bad, because it only covers the HealthKit-mirroring path, and it relies on HealthKit delivering an
  accurate, identical `date` to both sides.

## More Information

- Superseded by [ADR-0006](ADR-0006-single-owner-timer-state.md) (2026-10-25). The October 2026
  sync review found that only the receiving device used the canonical date, so the lockstep held
  on one side only.
- Follow-up that was considered here and later made moot by ADR-0006: carry the absolute anchor and frozen
  `remaining` in `TimerControlMessage`, with a `sentAt` staleness guard, so the WC path gets the
  same guarantee.
