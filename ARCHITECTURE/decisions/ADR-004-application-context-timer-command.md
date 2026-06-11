# ADR-004: Application context as the canonical timer-command channel

**Status**: Accepted
**Date**: 2026-06-11

## Context

Starting a timer on iPhone launches the Watch app reliably (via
`HKHealthStore.startWatchApp(toHandle:)`, which also starts the HK session), but the timer UI
on the Watch depends on a `StartTimerMessage` over WatchConnectivity. When the Watch app is not
already running, `WCSession.sendMessage` fails immediately (`isReachable == false`), leaving
only `transferUserInfo` — a FIFO queue with **no delivery-time guarantee**. When that queue
lagged, the Watch showed the preset list with a silent HK session running and no timer: the
reported "Watch opens but doesn't start a timer" bug.

`transferUserInfo` is also semantically wrong for this job: the "current timer" is *state*, not
a stream of events. A queue happily delivers stale starts (one per start, in order) hours
later; only the latest command ever matters.

## Decision

Use `WCSession.updateApplicationContext` as the canonical "current timer command" channel for
the iPhone → Watch direction:

- **Start**: iPhone publishes the `StartTimerMessage` as the application context (and still
  sends it via `sendMessage` as the low-latency fast path when the Watch is reachable).
- **Stop**: iPhone publishes a `StopTimerMessage` as the new context. WCSession has no "clear
  context" API, so *overwriting* with a stop is how a start is superseded.
- **Watch consumption**: `session(_:didReceiveApplicationContext:)` feeds the existing message
  pipeline; additionally, `activationDidCompleteWith` reads `receivedApplicationContext` —
  this is the cold-launch path where the persisted context is already waiting when the app
  starts.

Staleness and duplication are handled in `WatchMessageCoordinator`:

- `StartTimerMessage.isExpired(asOf:)` — a command whose `scheduledStartTime + totalDuration`
  lies in the past describes a finished workout and is dropped.
- Correlation-ID dedup: starts already handled, or whose ID was already stopped, are dropped.
  The previous identity + 10 s window dedup remains as a fallback for nil-correlation messages.

`transferUserInfo` remains in use for the Watch → iPhone direction
(`WorkoutSessionEndedMessage`), where queued *event* semantics are exactly right.

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep `transferUserInfo` (status quo) | No change | No delivery-time guarantee; delivers stale starts; caused the bug |
| Retry `sendMessage` on reachability change | Small change | Band-aid: still racy, needs pending-message bookkeeping, doesn't survive app relaunch |
| Watch pulls state from iPhone on launch | Works even without context | Extra round trip + new message types; Watch→iPhone wake adds latency before the timer can show |
| `updateApplicationContext` (chosen) | Latest-state-wins matches the domain; persisted; delivered at launch/activation | Needs staleness + dedup rules; no explicit "clear" (solved by stop-as-overwrite) |

## Consequences

### Positive
- A timer started on iPhone presents on the Watch even when the Watch app was cold-launched —
  the context is persisted and read at activation, no delivery race.
- Stale starts can no longer pile up in a queue and replay later.
- A Watch relaunched mid-workout re-joins the live workout at the correct elapsed position
  (combined with the anchored `start(at:)` late join).

### Negative
- The context is not refreshed on pause, so an unusually long-paused workout
  (paused beyond its remaining duration) can be misjudged as expired by a late-joining Watch.
  Accepted: rare, and the failure mode is "no timer presented", not a wrong timer.

### Neutral
- Dual delivery (fast path + context) means the coordinator must dedup; it already did for
  the previous dual-delivery design, now keyed by correlation ID.

## Future Direction

If pause-aware staleness ever matters, the iPhone could republish the context on pause/resume
with an adjusted horizon, at the cost of more context churn.
