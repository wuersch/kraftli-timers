# UC-0015: Run a training session

- **Status:** implemented
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to work through a whole session, from warm-up to the last set,
  as one workout with my Watch measuring it, so I don't have to start each timer separately and my
  training shows up as one workout in Apple Health.
- **Scope:** Kraftli Timers (iPhone app + Watch app)
- **Level:** user-goal

## Stakeholders and Interests

- Athlete: each step behaves like the same timer started on its own; stats per exercise keep
  working; one Health workout per training.
- Athlete's Apple Health record: one workout per session, with heart rate and calories whenever
  the Watch tracked it.

## Preconditions

- At least one session exists ([UC-0013](UC-0013-compose-a-training-session.md)).

## Success Guarantee

- Every step of the session was run or deliberately skipped, in order, with every loop repeated
  its number of rounds.
- The history holds one entry per completed step, as if the step had been run from a preset, and
  each entry is marked with the session's name ([UC-0005](UC-0005-record-a-workout.md)).
- Apple Health holds exactly one workout for the whole session, from the start of the first step to
  the end of the last, with heart rate and active calories when the Watch tracked it. The time
  the session waits for the athlete between steps counts as paused; a loop's rests and changeovers
  don't.
- The athlete has seen a summary of the session.

## Minimal Guarantee

- A session ended early keeps the entries of the steps completed so far. The current step is
  recorded as stopped early under the usual rule, otherwise not at all
  ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b). The Health workout covers the time up
  to the end.

## Trigger

The athlete starts a session on the iPhone.

## Main Success Scenario

1. System offers the session planned for today ([UC-0014](UC-0014-plan-the-training-week.md)).
2. Athlete starts it.
3. System starts the session on the Watch, as for a single workout
   ([UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md) steps 1–2). The Watch tracks
   heart rate and calories while a step or a loop's rest runs.
4. System shows the next step: its kind, exercise and settings, and the athlete's position in the
   session.
5. Athlete starts the step when ready.
6. System runs the step exactly as the matching single workout runs, on both devices
   ([UC-0001](UC-0001-run-an-emom-workout.md), [UC-0002](UC-0002-run-an-amrap-workout.md),
   [UC-0012](UC-0012-run-a-for-time-workout.md) steps 3–9), except that it returns to the session
   instead of showing the single-workout summary.
7. System records the step ([UC-0005](UC-0005-record-a-workout.md)), pauses the session, and shows
   the step's result together with the next step.
   Steps 4–7 repeat for each step, each round of a loop in turn.
8. After the last step, System ends the session. If every step was completed, it plays the
   completion sound and, if enabled, shows confetti.
9. The Watch saves one Health workout for the whole session ([UC-0005](UC-0005-record-a-workout.md)).
10. System shows the session summary: the session's name, total time, the result of each step,
    and active calories and average/maximum heart rate.
11. Athlete closes the summary.

## Extensions

- 1a. No session is planned for today, or the athlete wants another one:
  - 1a1. Athlete chooses any session.
  - 1a2. Use case continues at step 2.
- 3a. No Watch is available, or it doesn't confirm:
  - 3a1. The iPhone runs the session itself, as in [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md)
    extension 1a. No heart rate or calories are tracked.
  - 3a2. Use case continues at step 4.
- 4a. The next step opens a loop (the first step of its first round):
  - 4a1. System shows the whole loop instead: its number of rounds, every step with its kind,
    exercise and settings, and the rest between rounds if it has one. The Watch shows the loop in
    short: its rounds, its number of steps and the first exercise.
  - 4a2. Use case continues at step 5.
- 5a. Athlete skips the step:
  - 5a1. The skipped step isn't recorded. System moves on to the next step; after the last step,
    the session ends as in step 8.
  - 5a2. Use case continues at step 4.
- 5b. Athlete ends the session:
  - 5b1. System ends the session. Steps already completed stay recorded.
  - 5b2. Use case continues at step 9.
- 6a. Athlete ends the running step early:
  - 6a1. System records it as stopped early under the usual rule
    ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b).
  - 6a2. Use case continues at step 7.
- 7a. The step was completed inside a loop, and another step of the same loop follows:
  - 7a1. System doesn't pause the session. It records the step and shows the next step on both
    devices for a short changeover (2 s), or, after a round's last step in a loop with a rest,
    counts that rest down on both devices. Athlete may cut a rest short.
  - 7a2. System starts the next step without waiting for the athlete.
  - 7a3. Use case continues at step 6.
- 7b. A changeover or a rest ran out unnoticed (the app wasn't active, and more than 5 s have
  passed since):
  - 7b1. System pauses the session as of the moment the changeover or rest ran out.
  - 7b2. Use case continues at step 4.
- 7c. Athlete stays between steps, however long:
  - 7c1. The session stays paused: the time counts toward neither the Health workout's active
    time nor any step's entry, and heart rate and calories aren't tracked. The session doesn't
    end by itself.
  - 7c2. Use case continues at step 5.
- 9a. The Watch didn't track the session:
  - 9a1. The iPhone saves the Health workout without heart rate and calories
    ([UC-0005](UC-0005-record-a-workout.md) extension 3c).
  - 9a2. Use case continues at step 10.

## Special Requirements

- Sessions are started only on the iPhone. The Watch follows and can control a running step
  (pause, resume, count, done, end) as in [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md).
  Starting the next step, skipping a step and ending the session between steps happen on the
  iPhone only; between steps, the Watch shows what comes next and can only end the session.
- Inside a loop the session waits for the athlete only where the flow was broken: after a step
  that was skipped, stopped early or ended too early to be recorded (extensions 5a and 6a lead to
  step 7 and on to step 4, not to extension 7a). A loop's first step and the step after its last
  one are started by the athlete, like any step outside a loop.
- The Watch can always be freed from a session it tracks: between steps, the athlete can end the
  session on the Watch. The Watch saves the Health workout as far as it got, and the session
  ends on the iPhone too, as when ended there (extension 5b), as soon as the iPhone learns of it.
- Single preset workouts on the Watch alone ([UC-0004](UC-0004-run-a-workout-on-apple-watch.md))
  are unaffected.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#session-runner).
- Architecture: one device owns each step's timer state ([ADR-0006](../adr/ADR-0006-single-owner-timer-state.md));
  the session is a sequence the iPhone drives, and the first step's owner holds its Health
  workout ([ADR-0012](../adr/ADR-0012-session-as-iphone-driven-sequence-of-steps.md)).
- Requires revisions of:
  [UC-0005](UC-0005-record-a-workout.md) (entries per step marked with the session; one Health
  workout per session), [UC-0008](UC-0008-review-workout-stats.md) (show the session on an entry).
