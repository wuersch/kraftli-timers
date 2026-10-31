# UC-0011: Clear stored data

- **Status:** implemented
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to wipe my workout history, my presets, or both, to start fresh.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- None.

## Success Guarantee

- The chosen data is gone from the app on all the athlete's devices.
- Preferences and Apple Health are unchanged.

## Minimal Guarantee

- Nothing is deleted without the athlete's explicit confirmation.
- If deleting fails, the athlete is told and can try again.

## Trigger

The athlete asks to clear stored data ([UC-0010](UC-0010-configure-app-preferences.md)).

## Main Success Scenario

1. System offers three choices, each showing how many items it would delete:
   - workout history
   - timer presets
   - all data (both)
2. Athlete chooses what to clear.
3. System asks for confirmation. It states the number of items and that the deletion can't be undone.
4. Athlete confirms.
5. System deletes the chosen data, and the deletion reaches all of the athlete's devices.

## Extensions

- 1a. There is nothing to delete for a choice:
  - 1a1. System doesn't offer that choice.
  - 1a2. Use case continues at step 2.
- 4a. Athlete declines the confirmation:
  - 4a1. Nothing is deleted.
  - 4a2. Use case ends.
- 5a. The deletion can't be saved:
  - 5a1. System reports that the changes couldn't be saved and asks the athlete to try again.
  - 5a2. Use case ends.

## Special Requirements

- Clearing data never removes workouts from Apple Health and never resets preferences.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#settings)
- Sync: [ADR-0008](../adr/ADR-0008-swiftdata-cloudkit-persistence.md)
