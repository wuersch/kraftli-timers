# UC-0008: Review workout history and stats

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to see how much I've trained recently, overall, per muscle group
  and per exercise, so I can judge my consistency and balance.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- None. The history may be empty.

## Success Guarantee

- The athlete has seen the totals for the chosen period, computed from every recorded workout in
  that period. That includes workouts stopped early, which count like any other workout.

## Trigger

The athlete wants to review their training.

## Main Success Scenario

1. Athlete asks for their stats.
2. System offers four periods and selects "7 Days" by default:

   | Period | Covers | Activity breakdown |
   |--------|--------|--------------------|
   | 7 Days | today and the 6 days before | one value per day (7) |
   | Month | today and the 27 days before | one value per day (28) |
   | 6 Months | the current month and the 5 before | one value per month (6) |
   | Year | the current month and the 11 before | one value per month (12) |

   Each period covers whole days or whole months.
3. Athlete chooses a period.
4. For the period, System shows:
   - the total training time in minutes, and the number of workouts
   - the training time per muscle group (full body, upper body, lower body, core)
   - the training minutes per day or month as an activity breakdown
   - the training per exercise: minutes, number of workouts and total reps or rounds, ordered by minutes, highest first.
     Reps from EMOM and For Time workouts add up; workouts recorded without reps or rounds count
     toward minutes and workouts only.
5. Athlete asks for one exercise's workouts.
6. System lists that exercise's workouts in the chosen period. Each shows its date, duration, and
   reps or rounds if recorded, names its session if it was a step of one
   ([UC-0015](UC-0015-run-a-training-session.md)), and is marked if it was stopped early.
7. Athlete may correct or delete a listed workout ([UC-0009](UC-0009-correct-or-delete-a-logged-workout.md)).

## Extensions

- 1a. No workout has been recorded yet:
  - 1a1. System says there are no workouts yet and that completing one will produce stats.
  - 1a2. Use case ends.
- 4a. The chosen period has no workouts:
  - 4a1. System shows zero totals, and says there are no exercises in this period.
  - 4a2. Use case continues at step 3.
- 4b. A workout's exercise is no longer in the library (e.g. "Unknown"):
  - 4b1. The workout counts toward the totals and appears under its recorded name, but not under
    any muscle group.
  - 4b2. Use case continues at step 5.
- 4c. A muscle group's time reaches 60 minutes or more:
  - 4c1. System shows it in whole hours, rounded down.
  - 4c2. Use case continues at step 5.
- 5a. Athlete asks for all workouts instead:
  - 5a1. System lists every recorded workout, newest first, regardless of the period.
  - 5a2. Use case continues at step 7.

## Special Requirements

- Workout times add up to the second; totals are rounded down to whole minutes only for display,
  so short workouts, such as a 45-second For Time, still count.
- Exercises are matched to muscle groups by the name recorded with the workout.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#stats)
- Known deviations (fix candidates):
  - Workouts stopped early don't exist yet ([UC-0005](UC-0005-record-a-workout.md)).
  - Each workout is rounded down to whole minutes before the totals are added up, so workouts
    under a minute add nothing (Special Requirements).
- The stats approach is planned to be reworked; a revision of this use case is expected.
