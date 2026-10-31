# UC-0007: Choose an exercise for a preset

- **Status:** implemented
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to find a suitable bodyweight exercise and learn what it involves,
  so the preset I'm building names the right one.
- **Scope:** Kraftli Timers (iPhone app + Watch app)
- **Level:** subfunction

## Preconditions

- Athlete is creating or changing a preset ([UC-0006](UC-0006-manage-timer-presets.md)).

## Success Guarantee

- The preset refers to the chosen exercise from the library.

## Trigger

The athlete asks to choose the preset's exercise.

## Main Success Scenario

1. System lists the exercise library alphabetically and marks the currently chosen exercise. The
   library is a curated set of bodyweight exercises (22 in this release), each with a name, a
   description, a muscle group (full body, upper body, lower body or core) and, optionally, a
   difficulty (beginner, intermediate or advanced).
2. Athlete narrows the list by muscle group and/or difficulty.
3. System shows only the exercises that match all chosen criteria, and indicates that a filter is active.
4. Athlete asks for an exercise's details.
5. System shows its description, muscle group and difficulty.
6. Athlete chooses the exercise.
7. System assigns it to the preset and returns to the preset.

## Extensions

- 1a. The library couldn't be loaded:
  - 1a1. System says that no exercises are available.
  - 1a2. Use case ends.
- 2a. Athlete doesn't need to filter:
  - 2a1. Use case continues at step 4.
- 2b. Athlete chooses on the Watch:
  - 2b1. System offers the full list with name and muscle group only; there is no filter and no details.
  - 2b2. Use case continues at step 6.
- 3a. No exercise matches the criteria:
  - 3a1. System says no exercises match and offers to clear the filters.
  - 3a2. Use case continues at step 2.
- 3b. Athlete resets the filters:
  - 3b1. System shows the full list again.
  - 3b2. Use case continues at step 4.
- 4a. Athlete already knows the exercise:
  - 4a1. Use case continues at step 6.
- 6a. Athlete leaves without choosing:
  - 6a1. The preset keeps its previous exercise.
  - 6a2. Use case ends.

## Special Requirements

- The library ships with the app and is read-only. A new app version may change it; exercises
  aren't created, edited or synced by the athlete ([ADR-0009](../adr/ADR-0009-bundled-exercise-library.md)).
- Filters start cleared each time the athlete chooses an exercise.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#exercise-selection)
- Out of scope (backlog): showing each exercise's bundled form tips ("Form Tips During Workout",
  [backlog](../backlog.md)).
