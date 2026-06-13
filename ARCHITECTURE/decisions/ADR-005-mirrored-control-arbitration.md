# ADR-005: HealthKit is the sole control channel while a mirrored session is active

**Status**: Accepted
**Date**: 2026-06-13

## Context

Pause / resume / stop for a mirrored workout timer can travel over **two independent control
planes**:

1. **WatchConnectivity (WC)** — `TimerControlMessage` sent via `sendMessage` (immediate, but
   best-effort and reachability-dependent).
2. **HealthKit mirrored-session transitions** — `HKWorkoutSession.pause()/resume()` propagated to
   the companion device and delivered through `HKWorkoutSessionDelegate`, carrying a canonical
   transition `date` identical on both devices.

[ADR-003](ADR-003-cross-device-timer-anchoring.md) fixed the *anchoring math*: reconcile sites
re-anchor `pause(at:)` / `resume(at:)` off the shared HK transition `date` so repeated pause/resume
no longer drifts. But it did not arbitrate *between the two channels*, and whichever arrives first
wins. Two failures fall out of that unresolved race (issue #44):

- **Background desync (finding 3).** On iPhone, scenePhase `.background` fired a bare local
  `timerModel.pause()` with no mirrored pause and no `.active` handler. While mirrored, the Watch +
  HK session kept running and the mirrored state never changed, so `reconcileMirroredState` never
  fired. On unlock the iPhone re-anchored from the frozen time and stayed behind the Watch by the
  entire background duration. Locking the phone mid-workout is routine.
- **Fast-path pre-emption (finding 9).** The Watch emits *both* an HK transition and an
  unconditional WC `TimerControlMessage` on pause/resume. On iPhone, when the WC message wins
  (common — `sendMessage` is immediate), the receiver did a local-clock `timerModel.pause()`; the
  subsequent HK reconcile then no-oped on its `isRunning` guard, so the canonical
  `pause(at: transitionDate)` from ADR-003 never ran and per-cycle, latency-sized drift returned.

The iPhone-*initiated* side already prefers HK while mirrored (`handleTap` / `handleLongPress` /
`startCountdown` call `mirroredWorkout.pause()/resume()` and only fall back to WC when no session
exists). The gap was purely on the **receiving** and **lifecycle** sides.

## Decision

**While an HK workout session is active, HK transitions are the sole pause/play control channel;
inbound WC pause/play is ignored.** Applied symmetrically on both devices:

- **iPhone receiver** (`EMOMTimerView` / `AMRAPTimerView` `setupControlSubscription`): the WC
  `onPause` / `onPlay` callbacks early-return when `mirroredWorkout?.hasActiveSession == true`.
- **Watch receiver** (`WatchWorkoutCoordinator.handleRemoteControl`): WC `.play` / `.pause` are
  ignored while `sessionManager.sessionState` is `.running` / `.paused`. (No-op in practice today,
  since iPhone already prefers HK and never sends a competing WC pause while mirrored — kept for a
  uniform, future-proof invariant.)
- **Background lifecycle** (`TimerLifecycleModifier`): on `.background`, skip the local auto-pause
  while a mirrored session is active (the timer is wall-clock anchored to `startDate`, so the
  display self-corrects on foreground); on `.active`, re-run reconciliation so local state snaps to
  the live session after any background interval.

WC remains the channel for actions HealthKit has no equivalent for: **stop** (terminal; not subject
to drift) and AMRAP **increment-round** (workout *data*, not a control transition). The WC
pause/play fallback is still used when **no** HK session exists (e.g. HealthKit unavailable),
exactly as ADR-003 left it.

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Stop sending the WC pause/play from the Watch entirely (single channel at the source) | Removes the race at its origin | The WC message is still the right fallback when no HK session exists; removing it would regress the no-HK path. Receiver-side gating keeps both paths |
| Order/timestamp the two channels and pick the freshest | Channel-agnostic | Needs a `sentAt`/sequence protocol and a staleness window on a best-effort transport; larger surface than "HK wins while active", which the canonical-date reconcile already supports |
| Pause the mirrored session on background instead of skipping (finding 3) | Keeps both devices paused while phone is locked | Changes workout semantics (locking the phone would pause the Watch wearer's running workout); skipping preserves the wall-clock-anchored run, which is what the user expects |
| **HK is the sole control channel while a session is active (chosen)** | Root-cause arbitration; reuses ADR-003's canonical-dated reconcile; small, contained diff; no wire/protocol changes; symmetric and easy to reason about | WC's immediate fast path is dead while mirrored, so pause/play now pay HK propagation latency (reliable, and the canonical date keeps both sides in lockstep regardless) |

## Consequences

### Positive
- Findings 3 and 9 are fixed as direct corollaries of one rule.
- Locking the iPhone mid-workout no longer leaves it permanently behind the Watch.
- Repeated pause/resume on the common (WC-wins) path no longer reintroduces ADR-003 drift — the
  canonical `pause(at:)` / `resume(at:)` always runs.
- The arbitration rule is uniform across devices, so future control paths inherit it.

### Negative
- Pause/play while mirrored no longer benefit from WC's immediate delivery; they wait on HK
  propagation. Accepted: HK is reliable and canonical-dated, so correctness wins over the few-ms
  latency saved by the fast path.

### Neutral
- Stop and AMRAP increment-round are deliberately *not* gated and keep flowing over WC.
- The no-HK WC fallback (ADR-003's accepted limitation) is unchanged.
- Skipping the background auto-pause relies on the timer being wall-clock anchored (ADR-003); the
  `.active` reconcile is a belt-and-suspenders snap on top of the now-correct anchoring.

## Future Direction

If the no-HK WC fallback ever needs the same drift-free guarantee, carry the absolute anchor and
frozen `remaining` in `TimerControlMessage` with a `sentAt` staleness guard (the unification
sketched in ADR-003's Future Direction) — at which point the "HK wins" rule generalizes to "the
authoritative, canonical-dated channel wins", whichever transport carries it.
