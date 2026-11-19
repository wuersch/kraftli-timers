# ADR-0012: Run a session as an iPhone-driven sequence of separately owned steps, with one Health session held by the first step's owner

- **Status:** implemented
- **Date:** 2026-11-19
- **Deciders:** Michael Würsch

## Context and Problem Statement

A training session ([UC-0015](../use-cases/UC-0015-run-a-training-session.md)) runs several timers
back to back, with waits in between, and must end up as one Apple Health workout. The timer
machinery is built for exactly one workout: one device owns one `TimerState`, identified by one
workout ID, and the Watch starts, ends and saves its `HKWorkoutSession` with that workout
([ADR-0006](ADR-0006-single-owner-timer-state.md)).

Does ownership, and with it the replicated state, span the whole session or each step? And how
does the Watch keep one Health session across steps it otherwise knows nothing about?

## Decision Drivers

- Between steps, only the iPhone decides anything: start, skip and end happen there. The Watch
  only shows what comes next.
- A step must behave exactly like the same timer started on its own, on both devices.
- The sync layer (reducer, inbox, conflict rules of [ADR-0007](ADR-0007-optimistic-viewer-control.md))
  is the best-tested code in the app. The Watch's end-of-workout path has no tests.
- Apple Health must hold one workout per session, with the waits between steps as pauses.
- The session runner on the iPhone must work without a Watch, and was built first.

## Considered Options

- Per-step ownership: every step is an ordinary workout of its own; a session is a sequence the
  iPhone drives
- Session-level ownership: one replicated session state that contains the current timer, with
  the session's ID as the sync key

## Decision Outcome

Chosen option: **per-step ownership**, because between steps there is a single writer, the iPhone,
so nothing there needs conflict resolution, and re-keying the sync layer from workout to session
would put its tested behaviour at risk for no requirement. Three rules make it one session:

1. **Each step is a workout of its own.** It has its own workout ID, `TimerState` and revisions,
   and goes through the start request as a single workout does. `TimerState`, the reducer and
   the inbox stay as they are.
2. **The first step's owner holds the session's Health workout, to the end.** If the Watch owns
   the first step, it keeps its `HKWorkoutSession` open for the whole run, paused between steps
   and running through steps and loop rests, and saves one workout when the session ends. The
   start request of a step names the run it belongs to; a Watch that already holds that run
   takes ownership at once instead of starting another Health session. If the iPhone owns the
   first step, every later step stays on the iPhone and the iPhone saves the workout.
   A later step the Watch doesn't answer in time runs on the iPhone as usual, but the Health
   workout stays with the Watch: it does not yield its session for a run it holds.
3. **The Watch learns the session's progress from the iPhone, one way.** On every change of
   phase the iPhone sends a numbered `SessionStatus` (up next, running, resting until, finished).
   The Watch never answers it and never changes a session. From it the Watch pauses and resumes
   its Health session, ends and saves it, and shows what comes next.

### Consequences

- Good, because single workouts, the reducer, the inbox and the conflict rules are untouched.
- Good, because the iPhone-only runner needed no rework: the Watch is an addition to it.
- Good, because the Watch's decisions for a session sit in one small type driven by messages,
  which is tested without HealthKit.
- Bad, because a session has no single replicated record. The step's state, the session status
  and the Health session are three things kept in step by convention, and the iPhone is the
  session's owner in fact without that being enforced by the sync layer.
- Bad, because the Watch's Health session depends on a message to end. If the iPhone app dies
  mid-session, the Watch keeps a paused session until the next workout starts and saves it then,
  or until the Watch app is relaunched and recovers it.
- Bad, because every step repeats the start request. On a poor connection a later step can fall
  back to the iPhone while the Watch holds the Health workout; that step is then timed on the
  iPhone, and the Watch tracks it only if it still receives the session status.
- Bad, because an iPhone and a Watch on different app versions don't run sessions correctly:
  an older Watch treats every step as a workout of its own and saves one Health workout per step.
  Both apps ship together, so this is accepted.

### Confirmation

- `WatchSessionTests` cover the Watch's side of rules 2 and 3 with fake Health closures;
  `SessionRunnerTests` cover what the iPhone sends and who saves.
- On devices: one session with the Watch must produce exactly one Health workout with heart rate,
  linked to every step's history entry.

## Pros and Cons of the Options

### Per-step ownership

- Good, because it reuses the handshake, the state and both timer screens unchanged.
- Good, because a session can be built and shipped in slices: iPhone alone first, Watch after.
- Bad, because the session's progress travels beside the synced state, not inside it.
- Bad, because the Watch's Health session outlives the workouts it was built to belong to, so
  the starter and the workout screen each need a "this is a session's step" path.

### Session-level ownership

- Good, because both devices would derive everything from one record: one source of truth.
- Good, because a single workout would become a session of one step, one code path.
- Bad, because the workout ID is today the sync key, the history entry's ID and the Health
  link at once. Separating them touches the inbox, both starters, the controller and the messages.
- Bad, because the timer models take their configuration when created, so a state that changes
  its timer under them needs them rebuilt or reworked.
- Bad, because two wire formats would have to coexist while both forms are in use.

## More Information

- Builds on [ADR-0006](ADR-0006-single-owner-timer-state.md) and
  [ADR-0007](ADR-0007-optimistic-viewer-control.md), which stay in force per step.
- [ADR-0002](ADR-0002-healthkit-integration.md): the Health session on the Watch.
- [UC-0005](../use-cases/UC-0005-record-a-workout.md) extension 3d: one Health workout per session.
