# ADR-003: Cross-device timer anchoring via HealthKit's canonical transition date

**Status**: Accepted
**Date**: 2026-05-26

## Context

A mirrored workout timer runs as **two independent model instances** — one on iPhone, one on
Watch. A *running* timer is anchored to an absolute `startDate`, and the display derives from
`remaining = totalDuration − (now − startDate)`. System-synced device clocks plus the shared
`scheduledStartTime` handshake (`StartTimerMessage`) keep the *running* phase aligned.

Pause/resume broke this. On resume, each device independently recomputed its anchor from *its
own* clock at the instant *it* processed the event
(`TimerCoordinator.start(pausedTime:)`: `startDate = now − (totalDuration − pausedTime)`), and
pause captured each device's own elapsed time. Because pause/resume events cross devices with
latency, each side anchored to a slightly different point. When control alternated between
devices (pause on Watch, resume on phone), the per-cycle error was the *sum* of both latencies
and *systematic* — so repeatedly pausing/resuming made the two displayed times drift apart and
the error accumulated. Nothing re-synchronized after the initial handshake.

## Decision

Stop deriving the resume anchor from each device's local clock. Key the anchoring off an
**authoritative timestamp that is identical on both devices**: HealthKit's workout-session
transition `date`, delivered to both sides via
`HKWorkoutSessionDelegate.workoutSession(_:didChangeTo:from:date:)` (previously discarded).

- The HK observers (`MirroredWorkoutObserver` on iOS, `WorkoutSessionManager` on Watch) now
  expose `lastTransitionDate` from that delegate callback.
- The timer models gained `pause(at: Date)` / `resume(at: Date)` (on the `WorkoutTimer`
  protocol). On **pause**, each device freezes `remaining = totalDuration − (date − startDate)`.
  On **resume**, each re-anchors `startDate = date − (totalDuration − remaining)`.
- `TimerCoordinator` gained a `start(startDate:)` overload that adopts an explicit anchor
  **verbatim** (no recompute), plus an injectable `now: () -> Date` clock seam for deterministic
  tests.
- The reconcile sites (`reconcileMirroredState` on iOS, `reconcileSessionState` on Watch) call
  `pause(at:)` / `resume(at:)` with `lastTransitionDate` instead of the local-clock `pause()` /
  `start()`.

Because both inputs are shared across devices — `startDate` carried over from the prior cycle
and the canonical `date` — the recomputed anchor is identical on both sides every cycle. The
drift no longer accumulates; it stays bounded by the tiny, constant initial start skew.

**Scope: HK-mirroring path only.** Any iPhone-started workout, and any Watch-started workout
that mirrors to iPhone, runs an `HKWorkoutSession`, so pause/resume flows through the HK
delegate. The WCSession `TimerControlMessage` fallback (used only when *no* HK session exists)
is intentionally left unchanged — see Future Direction.

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Broadcast the absolute anchor over WCSession `TimerControlMessage` | Covers the no-HK fallback too; fully self-healing per message | Larger diff (message protocol, both sync services, control publishers, callbacks, ordering/staleness guard); WCSession ordering is best-effort and unreliable, the exact failure mode here |
| Periodic re-sync ticks (broadcast current `remaining` every N seconds) | Self-corrects any drift source | Continuous chatter; reconciliation jitter on the display; doesn't address the root cause, only masks it |
| **Anchor off HealthKit's canonical transition `date` (chosen)** | Root-cause fix; the shared timestamp already arrives on both devices reliably via HK; small, contained diff; no protocol/wire changes | Only covers the HK-mirroring path; relies on HK delivering an accurate, identical `date` to both sides |

## Consequences

What becomes easier or more difficult to do because of this change?

### Positive
- Repeated, alternating pause/resume on Watch and phone no longer drifts on the HK path.
- The timing core is now deterministically testable via the injected `now` clock seam.
- No changes to the message protocol, sync services, or control publishers — the wire stays simple.

### Negative
- The WCSession `TimerControlMessage` fallback (no active HK session) still re-anchors per
  device and can drift. This is an accepted known limitation (rare path).
- Remote-driven resume now routes through `resume(at:)`, which deliberately does **not** replay
  start feedback — a subtle behavioral split from the local resume path (`startAndScheduleHintHide`).

### Neutral
- `resume(at:)` preserves EMOM interval/warning state (`lastCompletedInterval`,
  `lastWarningTriggered`) so resuming never replays interval-complete or warning sounds.
- Reconcile sites keep their `if isRunning` / `!isRunning` guards, and the model methods
  self-guard, so a redundant `sessionManager.pause()`/`resume()` (driven off `isRunning` by the
  lifecycle modifiers) never bounces the HK session.

## Future Direction

If the no-HK fallback proves to matter in practice (e.g. HealthKit unavailable / unauthorized),
extend the same authoritative-timing idea to the WCSession path: carry the absolute anchor
(resume) and frozen `remaining` (pause) in `TimerControlMessage`, with a `sentAt` staleness
guard for ordering, and have the receiver adopt the values verbatim.
