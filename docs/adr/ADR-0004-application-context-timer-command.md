# ADR-0004: Use the application context as the canonical iPhone-to-Watch timer-command channel

- **Status:** superseded by ADR-0006
- **Date:** 2026-06-11
- **Deciders:** Michael Würsch

## Context and Problem Statement

Starting a timer on the iPhone launched the Watch app reliably via
`HKHealthStore.startWatchApp(toHandle:)`, which also starts the HealthKit session. The Watch's
timer UI, however, depended on a `StartTimerMessage` over WatchConnectivity. When the Watch app
wasn't already running, `WCSession.sendMessage` failed immediately (`isReachable == false`),
leaving only `transferUserInfo`, a FIFO queue with no guarantee of when it delivers. When that queue lagged, the
Watch showed the preset list with a silent HealthKit session running and no timer. This was the
reported "Watch opens but doesn't start a timer" bug.

`transferUserInfo` is also semantically wrong for this job. The "current timer" is *state*, not a
stream of events: a queue happily delivers stale starts hours later, and only the latest command
matters.

Which WatchConnectivity channel should carry the iPhone's current timer command so that a
cold-launched Watch presents it reliably?

## Decision Drivers

- A cold-launched Watch app must present the timer without a delivery race
- Stale starts must not pile up and replay later
- The channel's semantics should match the domain (latest state wins)

## Considered Options

- Keep `transferUserInfo` (status quo)
- Retry `sendMessage` on reachability change
- Watch pulls state from the iPhone on launch
- `updateApplicationContext` as the canonical command channel

## Decision Outcome

Chosen option: **`updateApplicationContext` as the canonical command channel**, because
latest-state-wins matches the domain, and the context is persisted and delivered at
launch/activation.

- **Start:** the iPhone publishes the `StartTimerMessage` as the application context. It still
  sends it via `sendMessage` as a fast path when the Watch is reachable.
- **Stop:** the iPhone publishes a `StopTimerMessage` as the new context. WCSession can't clear a
  context, so a start is superseded by overwriting it with a stop.
- **Watch:** `session(_:didReceiveApplicationContext:)` feeds the message pipeline, and
  `activationDidCompleteWith` reads `receivedApplicationContext` on cold launch.
- **Staleness and dedup** (`WatchMessageCoordinator`):
  - `StartTimerMessage.isExpired(asOf:)` drops starts whose `scheduledStartTime + totalDuration`
    has already passed.
  - Starts already handled, or already stopped, are dropped by correlation ID.
  - The older identity + 10 s window dedup remains for messages without a correlation ID.
- `transferUserInfo` stays for the Watch → iPhone direction (`WorkoutSessionEndedMessage`), where
  queued event semantics are right.

### Consequences

- Good, because a timer started on the iPhone presents on a cold-launched Watch: the context is
  persisted and read at activation.
- Good, because stale starts can no longer pile up and replay.
- Good, because a Watch relaunched mid-workout re-joins at the correct elapsed position (combined
  with the anchored late join).
- Bad, because the context isn't refreshed on pause. A workout paused beyond its remaining duration
  can be misjudged as expired by a late-joining Watch. This was accepted as rare, and the failure
  is "no timer presented", not a wrong timer.
- Neutral: dual delivery (fast path + context) means the coordinator must deduplicate, now keyed by
  correlation ID.

## Pros and Cons of the Options

### Keep `transferUserInfo`

- Good, because no change is needed.
- Bad, because there's no guarantee of when it delivers, it replays stale starts, and it caused the bug.

### Retry `sendMessage` on reachability change

- Good, because the change is small.
- Bad, because it is a band-aid: still racy, needs bookkeeping for pending messages, and doesn't
  survive an app relaunch.

### Watch pulls state from the iPhone on launch

- Good, because it works even without a context.
- Bad, because it needs an extra round trip and new message types, and waking the iPhone from the Watch adds
  latency before the timer can show.

### `updateApplicationContext`

- Good, because latest-state-wins matches the domain, and the context is persisted and delivered at
  launch.
- Bad, because it needs staleness and dedup rules, and has no explicit "clear" (solved by
  overwriting with a stop).

## More Information

- Superseded by [ADR-0006](ADR-0006-single-owner-timer-state.md) (2026-10-25), which keeps the
  application context as one of several snapshot transports. Snapshot revisions replace the
  staleness and dedup rules.
- Follow-up that was considered and later made moot: republish the context on pause/resume with
  an adjusted expiry, if pause-aware staleness ever mattered.
