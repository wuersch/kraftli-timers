# UC-0002: Run an AMRAP workout

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to complete as many rounds as possible in a set time and have
  them counted, so I can see and compare how much work I got done.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- An AMRAP preset exists with a duration of 1–60 whole minutes ([UC-0006](UC-0006-manage-timer-presets.md)).

## Success Guarantee

- The workout ran to the end of its duration, and every round the athlete counted before the end is in the total.
- The completed workout is recorded with its round count ([UC-0005](UC-0005-record-a-workout.md)).
- The athlete has seen a summary of the workout.

## Minimal Guarantee

- A workout ended early is recorded as stopped early once it had at least 1 minute of active time,
  otherwise not at all ([UC-0005](UC-0005-record-a-workout.md)).

## Trigger

The athlete starts an AMRAP preset.

## Main Success Scenario

1. Athlete starts an AMRAP preset.
2. System determines which device runs the workout
   ([UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md)). Without a paired Watch app,
   the iPhone runs it.
3. System counts down 3 seconds ("3, 2, 1, GO"), with an audible beep for each count.
4. System starts the workout.
5. System continuously shows the total time remaining, its progress, and the rounds counted so far.
6. Athlete completes a round and counts it.
7. System adds one to the round count and confirms the count with a haptic.
   Steps 6–7 repeat until the duration has elapsed.
8. When the duration has elapsed, System marks the workout as done and plays the completion sound.
   If confetti is enabled, System also shows it.
9. System records the completed workout with the round count ([UC-0005](UC-0005-record-a-workout.md)).
10. System shows the workout summary: kind, rounds and duration, plus active calories and
    average/maximum heart rate when a Watch tracked the workout.
11. Athlete closes the summary and returns to the presets.

## Extensions

- 3a. Athlete tries to count a round, pause or stop during the countdown:
  - 3a1. System ignores it.
  - 3a2. Use case continues at step 4.
- 5a. Athlete pauses the workout:
  - 5a1. System freezes the time and indicates that the workout is paused. Counting a round
    isn't possible while paused; asking to count resumes the workout instead.
  - 5a2. Athlete resumes the workout.
  - 5a3. System continues from the frozen time. Pause time doesn't count toward the duration.
  - 5a4. Use case continues at step 5.
- 5b. Athlete ends the workout before the duration has elapsed:
  - 5b1. System stops the workout, records it as stopped early
    ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b), and returns to the presets.
  - 5b2. Use case ends.
- 5c. The iPhone app moves to the background while the iPhone runs the workout:
  - 5c1. System pauses the workout. When the app returns to the foreground, it is still paused
    until Athlete resumes it, as in 5a2–5a3.
  - 5c2. Use case continues at step 5.
- 5d. The iPhone app moves to the background while a Watch owns the workout:
  - 5d1. The workout keeps running on the Watch. When the app returns, System shows the current
    time and rounds again.
  - 5d2. Use case continues at step 5.
- 6a. Athlete counted a round by mistake:
  - 6a1. The count can't be reduced during the workout. Athlete corrects it afterwards in the
    workout history ([UC-0009](UC-0009-correct-or-delete-a-logged-workout.md)).
  - 6a2. Use case continues at step 6.
- 7a. A round was counted just before the end but reached the owning device after it:
  - 7a1. System still counts it, because it was made before the end.
  - 7a2. Use case continues at step 8.
- 8a. Sound is switched off ([UC-0010](UC-0010-configure-app-preferences.md)):
  - 8a1. System gives no audible signals: no countdown beeps and no completion sound.
  - 8a2. Use case continues at step 9.
- 10a. Watch data is pending, missing, or available: as in [UC-0001](UC-0001-run-an-emom-workout.md)
  extensions 10a–10c.
  - 10a1. Use case continues at step 11.

## Special Requirements

- Same as [UC-0001](UC-0001-run-an-emom-workout.md): the display stays awake while running, and
  audio mixes with other audio.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#amrap-timer)
- [UC-0001](UC-0001-run-an-emom-workout.md), [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md),
  [UC-0004](UC-0004-run-a-workout-on-apple-watch.md)
- Known deviations (fix candidates): early stops are not recorded today (5b); the iPhone's countdown beeps ignore Sound off (extension 8a).
