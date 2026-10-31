# UC-0006: Manage timer presets

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to save, change, order and remove my favourite timer
  configurations, so I can start a workout with one action.
- **Scope:** Kraftli Timers (iPhone app + Watch app)
- **Level:** user-goal

## Preconditions

- None. The preset list may be empty.

## Success Guarantee

- The athlete's presets are stored, each with:
  - a kind (EMOM or AMRAP)
  - a duration of 1–60 whole minutes
  - an exercise
  - for EMOM, a rep count whose intervals last 3 seconds or longer
- The presets appear in the athlete's chosen order, identically on all their devices.

## Trigger

The athlete wants to create, change, reorder or remove a preset.

## Main Success Scenario

1. Athlete asks to create a new preset.
2. System proposes EMOM, 20 minutes, 100 reps, and the alphabetically first exercise.
3. Athlete chooses the kind, the duration and the exercise ([UC-0007](UC-0007-choose-an-exercise.md)),
   and for EMOM the rep count.
4. For EMOM, System shows the resulting interval length (duration ÷ reps) and offers only rep
   counts that keep each interval at 3 seconds or longer: at most 20 reps per minute of duration.
5. Athlete saves the preset.
6. System adds the preset at the end of the list. Each entry shows the kind and duration, and the
   exercise, plus the reps for EMOM.
7. System makes the preset available on the athlete's other devices.

## Extensions

- 1a. Athlete changes an existing preset:
  - 1a1. System presents the preset's current values.
  - 1a2. Use case continues at step 3.
- 1b. Athlete deletes a preset:
  - 1b1. System removes it immediately, without asking for confirmation, on all devices.
  - 1b2. Use case ends.
- 1c. Athlete reorders the presets (iPhone):
  - 1c1. System stores the new order and shows it on all devices.
  - 1c2. Use case ends.
- 1d. The list is empty, for example on first launch:
  - 1d1. System says there are no timers yet and invites the athlete to create the first one. No
    presets are provided by default.
  - 1d2. Use case continues at step 1.
- 3a. Athlete shortens the duration so that the chosen rep count would make intervals shorter than 3 seconds:
  - 3a1. System lowers the rep count to the new maximum.
  - 3a2. Use case continues at step 4.
- 3b. Athlete switches the kind to AMRAP:
  - 3b1. System no longer asks for a rep count; AMRAP presets have none.
  - 3b2. Use case continues at step 5.
- 3c. Athlete switches the kind to EMOM:
  - 3c1. System applies the rep limit of step 4 to the proposed rep count.
  - 3c2. Use case continues at step 4.
- 3d. Athlete abandons the change:
  - 3d1. System keeps the preset as it was.
  - 3d2. Use case ends.
- 6a. The preset is identical to an existing one (same kind, duration, reps and exercise):
  - 6a1. System keeps only one of them, at the latest on the next launch of the iPhone app.
    Identical presets aren't kept as separate entries.
  - 6a2. Use case continues at step 7.
- 6b. A preset's exercise no longer exists in the library:
  - 6b1. System shows the preset without an exercise name. The preset keeps working; workouts
    from it are recorded with the exercise "Unknown" ([UC-0005](UC-0005-record-a-workout.md)).
  - 6b2. Use case continues at step 7.

## Special Requirements

- Presets sync through the athlete's private iCloud database ([ADR-0008](../adr/ADR-0008-swiftdata-cloudkit-persistence.md)).
  The rules above apply identically on the iPhone and the Watch; only the input method differs.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#timer-preset-list) and [ui-spec.md](ui-spec.md#watch-app)
- Known deviation (fix candidate): switching an existing AMRAP preset to EMOM keeps the proposed
  100 reps even where they exceed the limit (extension 3c). For short durations this can save
  intervals under 3 seconds.
