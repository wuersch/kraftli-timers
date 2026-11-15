# ADR-0010: Open-ended workouts have no duration in the timer state and end with a `done` intent

- **Status:** implemented
- **Date:** 2026-11-15
- **Deciders:** Michael Würsch

## Context and Problem Statement

The single-owner timer state ([ADR-0006](ADR-0006-single-owner-timer-state.md)) assumes that every
workout is time-boxed. `TimerConfig.totalDuration` caps the elapsed time, the reducer marks the
workout completed when the elapsed time reaches it, and the owner schedules a completion check for
that moment. The only way to end a workout early is `stop`, which never counts as a completion.

For Time ([UC-0012](../use-cases/UC-0012-run-a-for-time-workout.md)) has no duration. It counts up
until the athlete declares it done, on either device, and that declaration *is* the completion.
How do the shared state and the intent protocol represent an open-ended workout and its
user-declared finish?

## Decision Drivers

- The state model is shared between iPhone and Watch and has about 15 call sites that assume a
  duration. Every one of them has to be revisited, and none may be missed silently.
- A done declared on the viewer must reach the owner through the existing intent protocol
  ([ADR-0007](ADR-0007-optimistic-viewer-control.md)), including the viewer's optimistic prediction.
- Keep it simple: two TestFlight users who update iPhone and Watch together, no old builds to
  support.

## Considered Options

- Optional `totalDuration` (nil = open-ended) and a `done` intent that records `.completed`
- `totalDuration == 0` as the open-ended sentinel and a `done` intent that records `.completed`
- Either of the above with a new `Finish` case (e.g. `.done(at:)`) instead of reusing `.completed`

## Decision Outcome

Chosen option: **optional `totalDuration` and a `done` intent that records `.completed`**, because
the compiler then flags every call site that assumed a duration, and the existing completion
handling (confetti, sound, logging, summary) already keys off `.completed`.

- **`TimerConfig.totalDuration: TimeInterval?`.** nil means open-ended. The elapsed time is clamped
  only below (at 0), the reducer never completes the workout by itself, and the owner schedules no
  completion check.
- **`TimerIntent.Action.done`.** The reducer applies it as `.completed(at:)` at the intent's tap
  time, clamped to `[lastTransitionAt, now]` like every other intent. It is ignored during the
  countdown, when tapped while paused, and once the workout has finished. A done tapped on the
  viewer before the owner paused still completes the workout, at the pause, so a completion the
  viewer already predicted is never rolled back. Time-boxed workouts ignore it.
- **No new `Finish` case.** "Done" is a completion; `stop` stays the early end.
- **Late done:** a done that reaches the owner after a later pause or resume there is moved to that
  transition instead of keeping the declared moment, an accepted deviation from UC-0012 7b. The
  error is at most the delivery delay.
- **No wire-version negotiation now.** It can be added later without a migration: a version field
  missing from an older build decodes as nil and identifies that build as legacy.
- **Persistence is unaffected.** `TimerConfig` is never stored. `TimerPreset.durationInterval`
  stays non-optional in the CloudKit schema and is 0 for For Time presets.

### Consequences

- Good, because every place that assumes a duration fails to compile until it handles the
  open-ended case.
- Good, because a done from the viewer gets optimistic prediction, deduplication and queued
  delivery from ADR-0007 without new rules.
- Good, because no new `Finish` case means no new completion paths in the timer models and views.
- Bad, because a late done can produce a finish time that is slightly too long (7b deviation).
- Bad, because an older build that receives a `done` intent or an open-ended config fails to
  decode it. This is acceptable only while all users update both devices together.
- Bad, because `durationInterval = 0` on a For Time preset is a stored sentinel, not a type-level
  "no duration".

### Confirmation

`ForTimeTests` cover `done` while running, during the countdown, while paused, before a later
owner pause, after finishing, and arriving late, and confirm that open-ended states never complete
by themselves.

## Pros and Cons of the Options

### Optional `totalDuration`

- Good, because the type says what the data means, and the compiler finds every call site.
- Bad, because every call site and test that builds or reads `TimerConfig` has to change.

### `totalDuration == 0` as sentinel

- Good, because the change is smaller and the wire format stays the same.
- Bad, because a forgotten check silently treats the workout as already completed (elapsed ≥ 0).

### New `Finish` case

- Good, because "done" and "ran out" stay distinguishable in the state.
- Bad, because every completion check in both apps needs another case, while no requirement
  distinguishes the two.

## More Information

- Amends [ADR-0006](ADR-0006-single-owner-timer-state.md) (state model) and
  [ADR-0007](ADR-0007-optimistic-viewer-control.md) (adds a `done` row to the reconciliation table).
- Requirements: [UC-0012](../use-cases/UC-0012-run-a-for-time-workout.md),
  [UC-0003](../use-cases/UC-0003-run-an-iphone-started-workout-with-the-watch.md),
  [UC-0004](../use-cases/UC-0004-run-a-workout-on-apple-watch.md).
