# UC-0005: Record a workout

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want every workout I do to land in my workout history and in Apple
  Health exactly once, so that my stats and my Activity Rings reflect the work I did.
- **Scope:** Kraftli Timers (iPhone app + Watch app)
- **Level:** subfunction

## Stakeholders and Interests

- Athlete: no workout lost, none duplicated; heart rate and calories included whenever the Watch
  tracked them; no invented data.
- Apple Health / third-party apps reading it (e.g. insurance reward programs): one accurate entry per workout.

## Preconditions

- A workout has ended, either because its duration elapsed or because the athlete ended it
  ([UC-0001](UC-0001-run-an-emom-workout.md), [UC-0002](UC-0002-run-an-amrap-workout.md),
  [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md),
  [UC-0004](UC-0004-run-a-workout-on-apple-watch.md)).

## Success Guarantee

- The workout history holds exactly one entry for the workout:
  - when it was done
  - the exercise name as it was at that time
  - the kind (EMOM or AMRAP)
  - its duration
  - reps completed (EMOM) or rounds counted (AMRAP)
- Apple Health holds exactly one workout for it, linked to the history entry. It covers the actual
  start, end and pauses, and includes heart rate and active calories when the Watch tracked it.
- The history entry is available on all of the athlete's devices.

## Minimal Guarantee

- The history entry is kept even if the Apple Health save fails.
- A workout never appears in Apple Health more than once.

## Trigger

A workout ends.

## Main Success Scenario

1. The workout's duration has elapsed.
2. The device on which the workout was started records the history entry. It has the full duration
   and the reps completed (EMOM) or rounds counted (AMRAP).
3. The device that ran the workout saves it to Apple Health as a high-intensity interval training
   workout (indoor), with its actual start, end and pauses. When that device is the Watch, the save
   includes the heart rate and active calories it tracked.
4. When the device that saved to Apple Health is not the one that recorded the history entry, it
   reports the Health workout and its heart rate and calories to the recording device.
5. System links the Apple Health workout to the history entry.
6. System makes the history entry available on the athlete's other devices.

## Extensions

- 1a. Athlete ended the workout early, after at least 1 minute of active time (pauses excluded):
  - 1a1. The entry records the active time so far, the reps completed or rounds counted so far, and
    marks the workout as stopped early.
  - 1a2. Use case continues at step 2.
- 1b. Athlete ended the workout during the countdown, or with less than 1 minute of active time:
  - 1b1. Nothing is recorded, neither in the history nor in Apple Health.
  - 1b2. Use case ends.
- 1c. The Watch app was terminated during a workout (crash or system kill) and is relaunched:
  - 1c1. The Watch saves the interrupted workout, with the heart rate and calories tracked so far,
    to Apple Health, ending at the time of recovery.
  - 1c2. No history entry is recorded, because the workout's details were lost with the app.
  - 1c3. Use case ends.
- 2a. The preset's exercise no longer exists:
  - 2a1. The entry records the exercise as "Unknown".
  - 2a2. Use case continues at step 3.
- 2b. The iPhone app was terminated while the Watch ran an iPhone-started workout:
  - 2b1. No history entry is recorded; the Watch's Apple Health workout exists without one. This
    is an accepted limitation.
  - 2b2. Use case continues at step 3.
- 3a. Access to Apple Health was denied on the device that ran the workout:
  - 3a1. The history entry is kept. System tells the athlete that the workout wasn't saved to
    Apple Health.
  - 3a2. Use case continues at step 6.
- 3b. The Apple Health save fails for another reason:
  - 3b1. The history entry is kept. System tells the athlete that the workout wasn't saved to
    Apple Health, as in 3a.
  - 3b2. Use case continues at step 6.
- 3c. The iPhone ran the workout:
  - 3c1. The Health workout contains no heart rate or calories. System never estimates them.
  - 3c2. Use case continues at step 6.
- 4a. The devices are out of contact when the workout ends:
  - 4a1. The report is delivered once contact returns, possibly after the athlete has left the summary.
  - 4a2. Use case continues at step 5.
- 4b. The report arrives more than once:
  - 4b1. System links it only once.
  - 4b2. Use case continues at step 6.
## Special Requirements

- Permission to use Apple Health is requested when it is first needed, never at app launch. On the
  iPhone this is the first Health save; on the Watch, the first workout start.
- History entries sync through the athlete's private iCloud database
  ([ADR-0008](../adr/ADR-0008-swiftdata-cloudkit-persistence.md)).
- The app's history is the source of truth; the Apple Health entry is a linked copy. Deleting a
  workout in Apple Health doesn't change the history.

## Related Information

- Architecture: [ADR-0002](../adr/ADR-0002-healthkit-integration.md),
  [ADR-0006](../adr/ADR-0006-single-owner-timer-state.md) (the device that runs the workout saves it to Health)
- Known deviations (fix candidates):
  - Early stops (1a) are not recorded today: the iPhone records nothing, and a Watch-run workout
    saves only a partial Health workout.
  - The iPhone's Health workout spans the nominal duration ending at completion, ignoring the
    actual start and pauses (step 3).
  - A failed or denied Health save is silent today (3a, 3b).
