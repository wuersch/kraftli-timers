# UC-0010: Configure app preferences

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to adapt the app's sound and visuals to where and how I train,
  for example quiet at home or loud in a gym, and look up information about the app.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- None.

## Success Guarantee

- The chosen preferences are stored on this iPhone and apply from the next workout on, except
  the launch animation (see 3c).

## Trigger

The athlete wants to change how the app behaves, or wants information about the app.

## Main Success Scenario

1. Athlete asks for the app's preferences.
2. System shows the current preferences:

   | Preference | Default | Effect |
   |------------|---------|--------|
   | Sound | on | Off silences all workout sounds (countdown, interval and completion) |
   | Cheer on completion | on | On: a crowd cheer at completion. Off: three neutral beeps. Only offered while Sound is on |
   | Launch animation | on | Shows the animated brand intro when the app starts |
   | Confetti | on | Celebrates a completed workout with confetti |
   | Smooth animations | on | Refreshes the timer display at the display refresh rate instead of five times per second |
   | Show reps in center (EMOM) | off | Shows the current rep and the total reps instead of the interval time |

3. Athlete changes a preference.
4. System stores it immediately; no separate save is needed.

## Extensions

- 1a. Athlete wants information about the app:
  - 1a1. System shows:
    - the app version and build
    - a link to the source code
    - a link to the privacy policy
    - acknowledgments for the third-party icon and sound used
  - 1a2. Use case ends.
- 3a. Athlete switches Sound off:
  - 3a1. System no longer offers the cheer preference, but remembers its value for when Sound is
    switched on again.
  - 3a2. Use case continues at step 4.
- 3b. Athlete wants to clear stored data:
  - 3b1. Use case continues in [UC-0011](UC-0011-clear-stored-data.md).
  - 3b2. Use case ends.
- 3c. Athlete changes the launch animation:
  - 3c1. The change applies the next time the app starts from scratch.
  - 3c2. Use case continues at step 4.

## Special Requirements

- Preferences are stored per device and don't sync. The Watch app has no preferences.

## Related Information

- Architecture: [ADR-0001](../adr/ADR-0001-settings-pattern.md)
- Interaction design: [ui-spec.md](ui-spec.md#settings)
- Known deviation (fix candidate): with Sound off, the iPhone's countdown still beeps.
