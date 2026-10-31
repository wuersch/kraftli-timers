# ADR-0005: Make HealthKit the sole pause/resume channel while a mirrored session is active

- **Status:** superseded by ADR-0006
- **Date:** 2026-06-13
- **Deciders:** Michael Würsch

## Context and Problem Statement

Pause, resume and stop for a mirrored workout timer could travel over two independent control
channels:

1. **WatchConnectivity (WC):** `TimerControlMessage` via `sendMessage`. Immediate, but
   best-effort and dependent on reachability.
2. **HealthKit mirrored-session transitions:** `HKWorkoutSession.pause()/resume()`, propagated to
   the companion and delivered through `HKWorkoutSessionDelegate` with a canonical transition date.

[ADR-0003](ADR-0003-cross-device-timer-anchoring.md) fixed the anchoring math. It didn't
arbitrate between the two channels: whichever arrived first won. Two failures followed
(issue #44):

- **Background desync.** On iPhone, going to the background ran a local `timerModel.pause()`, but
  no mirrored pause and no foreground handler. The Watch's session kept running, so the iPhone
  stayed behind the Watch after unlock by the entire background duration.
- **Fast-path pre-emption.** The Watch emitted both an HK transition and a WC message on
  pause/resume. When the WC message won (common), the iPhone paused on its local clock, the later
  HK reconcile skipped because of its `isRunning` guard, and ADR-0003's canonical `pause(at:)` never ran.

The iPhone-initiated side already preferred HealthKit while mirrored; the gap was on the receiving
and lifecycle sides.

Which channel decides pause/resume while both are available?

## Decision Drivers

- Fix both issue #44 findings with one rule
- Reuse ADR-0003's canonical-date reconcile
- Locking the iPhone must not pause the Watch wearer's workout
- No wire/protocol changes

## Considered Options

- Stop sending WC pause/play from the Watch entirely
- Order/timestamp the two channels and pick the freshest
- Pause the mirrored session when the iPhone goes to the background
- HealthKit is the sole pause/play channel while a session is active

## Decision Outcome

Chosen option: **HealthKit is the sole pause/play channel while a session is active**. One rule
fixes both findings, it reuses ADR-0003's reconcile, and it needs no protocol change.

- **iPhone receiver:** WC `onPause`/`onPlay` return early while
  `mirroredWorkout?.hasActiveSession == true`.
- **Watch receiver:** WC `.play`/`.pause` are ignored while the session is `.running`/`.paused`.
  This is a no-op today, kept so the rule holds the same way on both devices.
- **Background lifecycle:** skip the local auto-pause while a mirrored session is active, and
  re-run reconciliation on return to the foreground.
- **Stop** and AMRAP **increment-round** stay on WC, because HealthKit has no equivalent for them. The WC
  pause/play fallback remains when no HealthKit session exists.

### Consequences

- Good, because both findings are fixed by one rule, and locking the iPhone no longer leaves it
  behind the Watch.
- Good, because the canonical `pause(at:)`/`resume(at:)` always runs, so repeated pause/resume no
  longer reintroduces drift.
- Bad, because pause/play while mirrored lose WC's immediate delivery and wait on HealthKit
  propagation. This was accepted, because correctness matters more than a few milliseconds.
- Neutral: the no-HealthKit WC fallback, a limitation ADR-0003 accepted, is unchanged.

## Pros and Cons of the Options

### Stop sending WC pause/play from the Watch

- Good, because it removes the race where it starts.
- Bad, because WC is still the right fallback without a HealthKit session; removing it breaks that path.

### Order/timestamp the channels, freshest wins

- Good, because it doesn't care which channel delivers.
- Bad, because it needs a `sentAt`/sequence protocol and a staleness window on a best-effort
  transport, a larger change than "HK wins while active".

### Pause the mirrored session on iPhone background

- Good, because both devices stay paused while the iPhone is locked.
- Bad, because it changes workout semantics: locking the phone would pause the wearer's running workout.

### HealthKit is the sole pause/play channel while active

- Good, because it fixes the race at its root, reuses the canonical-date reconcile, and applies the same rule on both devices.
- Bad, because pause/play wait for HealthKit propagation while mirrored.

## More Information

- Superseded by [ADR-0006](ADR-0006-single-owner-timer-state.md) (2026-10-25). The October 2026
  sync review found the rule was evaluated against different signals per device ("I hold a mirrored
  session" vs. "my session is running"), so iPhone pause/play was still dropped before mirroring
  connected and after Bluetooth drops.
