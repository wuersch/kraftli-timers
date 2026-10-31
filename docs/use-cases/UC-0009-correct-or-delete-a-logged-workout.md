# UC-0009: Correct or delete a logged workout

- **Status:** implemented
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to fix a miscounted workout or remove one that shouldn't be in my
  history, so that my stats stay truthful.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- At least one workout is recorded, and the athlete is looking at a list of workouts
  ([UC-0008](UC-0008-review-workout-stats.md)).

## Success Guarantee

- The workout shows the corrected reps or rounds, or is gone from the history, on all the athlete's
  devices. The stats reflect the change.

## Minimal Guarantee

- Apple Health is never changed by corrections or deletions in the app.

## Trigger

The athlete picks a workout to correct, or decides to remove one.

## Main Success Scenario

1. Athlete picks a workout from a list.
2. System shows its date, time, exercise, duration in minutes, and kind (EMOM or AMRAP) as
   read-only information. Only the reps (EMOM) or rounds (AMRAP) can be changed.
3. Athlete sets the corrected value: 1–999 reps, or 1–99 rounds.
4. Athlete saves the correction.
5. System stores the new value. Stats and lists reflect it, on all devices.

## Extensions

- 1a. Athlete deletes a workout instead:
  - 1a1. System removes it from the history immediately, without asking for confirmation, on all devices.
  - 1a2. The workout's Apple Health entry, if any, stays in Apple Health.
  - 1a3. Use case ends.
- 3a. The recorded value lies outside the correctable range (e.g. 0 rounds for a workout stopped early):
  - 3a1. System keeps the recorded value unless the athlete chooses a value within the range.
  - 3a2. Use case continues at step 4.
- 4a. Athlete abandons the correction:
  - 4a1. The workout stays unchanged.
  - 4a2. Use case ends.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#workout-log-editor)
- AMRAP rounds can't be corrected during a workout; this use case is the way to correct them
  ([UC-0002](UC-0002-run-an-amrap-workout.md)).
