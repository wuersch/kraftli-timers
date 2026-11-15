# UC-0012: Run a For Time workout

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to do a fixed number of reps as fast as possible and have my
  time measured, so I can see and compare how quickly I got the work done.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- A For Time preset exists: an exercise and a rep count of 1–999
  ([UC-0006](UC-0006-manage-timer-presets.md)). It has no duration.

## Success Guarantee

- The workout ran until the athlete declared it done, and the finish time is the active time from
  the start to that moment, pauses excluded.
- The completed workout is recorded with the preset's rep count and the finish time
  ([UC-0005](UC-0005-record-a-workout.md)).
- The athlete has seen a summary of the workout, including the pace.

## Minimal Guarantee

- A workout ended without being declared done is recorded as stopped early once it had at least
  1 minute of active time, otherwise not at all ([UC-0005](UC-0005-record-a-workout.md)). It has no
  rep count, because the reps done so far are unknown.

## Trigger

The athlete starts a For Time preset.

## Main Success Scenario

1. Athlete starts a For Time preset.
2. System determines which device runs the workout
   ([UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md)). Without a paired Watch app,
   the iPhone runs it.
3. System counts down 3 seconds ("3, 2, 1, GO"), with an audible beep for each count.
4. System starts the workout.
5. System continuously shows the elapsed time, the exercise and the target rep count, and visibly
   indicates that the clock is running. It gives no signals during the workout; there is no
   interval to pace.
6. Athlete performs the reps as fast as possible, without reporting them to System.
7. Athlete declares the workout done after the last rep.
8. System stops the clock, marks the workout as done and plays the completion sound: a cheer, or
   three neutral beeps ([UC-0010](UC-0010-configure-app-preferences.md)). If confetti is enabled,
   System also shows it.
9. System records the completed workout with the preset's rep count and the finish time
   ([UC-0005](UC-0005-record-a-workout.md)).
10. System shows the workout summary: kind, reps, finish time and pace (seconds per rep), plus
    active calories and average/maximum heart rate when a Watch tracked the workout.
11. Athlete closes the summary and returns to the presets.

## Extensions

- 3a. Athlete tries to declare done, pause or stop during the countdown:
  - 3a1. System ignores it.
  - 3a2. Use case continues at step 4.
- 5a. Athlete pauses the workout:
  - 5a1. System freezes the elapsed time and indicates that the workout is paused. Declaring done
    isn't possible while paused.
  - 5a2. Athlete resumes the workout.
  - 5a3. System continues from the frozen time. Pause time doesn't count toward the finish time.
  - 5a4. Use case continues at step 5.
- 5b. Athlete ends the workout without declaring it done:
  - 5b1. System stops the workout, records it as stopped early with its active time and no rep
    count ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b), and returns to the presets.
  - 5b2. Use case ends.
- 5c. The iPhone app moves to the background while the iPhone runs the workout:
  - 5c1. System pauses the workout. When the app returns to the foreground, it is still paused
    until Athlete resumes it, as in 5a2–5a3.
  - 5c2. Use case continues at step 5.
- 5d. The iPhone app moves to the background while a Watch owns the workout:
  - 5d1. The workout keeps running on the Watch. When the app returns, System shows the current
    elapsed time again.
  - 5d2. Use case continues at step 5.
- 7a. Athlete declared done by mistake, before finishing the reps:
  - 7a1. The workout can't be continued, and its finish time can't be corrected afterwards. If the
    result shouldn't count, Athlete deletes the workout from the history
    ([UC-0009](UC-0009-correct-or-delete-a-logged-workout.md) extension 1a).
  - 7a2. Use case continues at step 8.
- 7b. Done was declared on one device but reached the owning device later:
  - 7b1. System uses the moment it was declared as the finish time.
  - 7b2. Use case continues at step 8.
- 8a. Sound is switched off ([UC-0010](UC-0010-configure-app-preferences.md)):
  - 8a1. System gives no audible signals: no countdown beeps and no completion sound.
  - 8a2. Use case continues at step 9.
- 9a. The finish time is under 1 minute:
  - 9a1. The workout is recorded like any other completed workout; the 1-minute minimum applies
    only to workouts stopped early.
  - 9a2. Use case continues at step 10.
- 10a. Watch data is pending, missing, or available: as in [UC-0001](UC-0001-run-an-emom-workout.md)
  extensions 10a–10c.
  - 10a1. Use case continues at step 11.

## Special Requirements

- Same as [UC-0001](UC-0001-run-an-emom-workout.md): the display stays awake while running, and
  audio mixes with other audio.
- The finish time is measured and recorded to the second. Stats add up recorded seconds and round
  only for display, so short For Time workouts still count toward the totals
  ([UC-0008](UC-0008-review-workout-stats.md)).

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#for-time-timer). No protection against an
  accidental "done" for now.
- [UC-0001](UC-0001-run-an-emom-workout.md), [UC-0002](UC-0002-run-an-amrap-workout.md) (the
  time-boxed counterparts), [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md),
  [UC-0004](UC-0004-run-a-workout-on-apple-watch.md)
- Requires revisions of: [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md) and
  [UC-0004](UC-0004-run-a-workout-on-apple-watch.md) (third kind, done declared on either device),
  [UC-0005](UC-0005-record-a-workout.md) (finish time instead of the preset duration; stopped
  early without reps), [UC-0006](UC-0006-manage-timer-presets.md) (For Time presets: reps 1–999,
  default 100, no duration), [UC-0008](UC-0008-review-workout-stats.md) (workouts without reps; sum seconds, round for display;
  finish time), [UC-0009](UC-0009-correct-or-delete-a-logged-workout.md) (For Time as a kind; its
  finish time stays read-only, like every duration).
- Known deviations (fix candidates): early ends are not recorded today (Minimal Guarantee, 5b), as
  for all kinds ([UC-0005](UC-0005-record-a-workout.md)); a done declared on one device that
  reaches the owning device after a later pause or resume there is moved to that pause or resume,
  not kept at the declared moment (7b).
