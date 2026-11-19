# UC-0015: Run a training session

- **Status:** approved
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
  between steps counts as paused.
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
4. System shows the first step: its kind, exercise and settings, and the athlete's position in the
   session.
5. Athlete starts the step when ready.
6. System runs the step exactly as the matching single workout runs, on both devices
   ([UC-0001](UC-0001-run-an-emom-workout.md), [UC-0002](UC-0002-run-an-amrap-workout.md),
   [UC-0012](UC-0012-run-a-for-time-workout.md) steps 3–9), except that it returns to the session
   instead of showing the single-workout summary.
7. System records the step ([UC-0005](UC-0005-record-a-workout.md)), pauses the session, and shows
   the step's result together with the next step.
   Steps 5–7 repeat for each step, each round of a loop in turn.
8. After the last step, System ends the session, plays the completion sound and, if enabled, shows
   confetti.
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
- 7a. A round of a loop ends and another follows:
  - 7a1. If the loop has a rest, System counts it down on both devices without pausing the session,
    and then shows the loop's first step again. Athlete may cut the rest short.
  - 7a2. Use case continues at step 5.
- 7b. Athlete stays between steps, however long:
  - 7b1. The session stays paused: the time counts toward neither the Health workout's active
    time nor any step's entry, and heart rate and calories aren't tracked. The session doesn't
    end by itself.
  - 7b2. Use case continues at step 5.
- 9a. The Watch didn't track the session:
  - 9a1. The iPhone saves the Health workout without heart rate and calories
    ([UC-0005](UC-0005-record-a-workout.md) extension 3c).
  - 9a2. Use case continues at step 10.

## Special Requirements

- Sessions are started only on the iPhone. The Watch follows and can control a running step
  (pause, resume, count, done, end) as in [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md).
  Starting the next step, skipping a step and ending the session between steps happen on the
  iPhone only; between steps, the Watch only shows what comes next.
- Single preset workouts on the Watch alone ([UC-0004](UC-0004-run-a-workout-on-apple-watch.md))
  are unaffected.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#session-runner).
- Architecture: one device owns the timer state ([ADR-0006](../adr/ADR-0006-single-owner-timer-state.md)).
  Whether that ownership spans the whole session or each step is a structural decision likely to
  need its own ADR.
- Requires revisions of:
  [UC-0005](UC-0005-record-a-workout.md) (entries per step marked with the session; one Health
  workout per session), [UC-0008](UC-0008-review-workout-stats.md) (show the session on an entry).
