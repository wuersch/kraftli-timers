# UC-0001: Run an EMOM workout

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to work through a fixed number of reps paced evenly over a set
  time, so I know when each rep is due without watching a clock.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- An EMOM preset exists: a duration of 1–60 whole minutes and a rep count that keeps each interval
  at 3 seconds or longer ([UC-0006](UC-0006-manage-timer-presets.md)).

## Success Guarantee

- The workout ran to the end of its duration, and the athlete was told of every interval boundary
  and of the completion.
- The completed workout is recorded ([UC-0005](UC-0005-record-a-workout.md)).
- The athlete has seen a summary of the workout.

## Minimal Guarantee

- A workout ended early is recorded as stopped early once it had at least 1 minute of active time,
  otherwise not at all ([UC-0005](UC-0005-record-a-workout.md)).

## Trigger

The athlete starts an EMOM preset.

## Main Success Scenario

1. Athlete starts an EMOM preset.
2. System determines which device runs the workout
   ([UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md)). Without a paired Watch app,
   the iPhone runs it.
3. System counts down 3 seconds ("3, 2, 1, GO"), with an audible beep for each count.
4. System starts the workout. It divides the duration into as many equal intervals as the preset
   has reps, one rep per interval.
5. System continuously shows the time remaining in the current interval, the total time remaining,
   and the progress of both.
6. System highlights the last 3 seconds of each interval. The highlight is visual only; no sound plays.
7. At each interval boundary, System signals the next rep with a beep and advances the rep count.
   Athlete performs one rep per interval and rests for the rest of it.
8. When the duration has elapsed, System marks the workout as done and plays the completion sound:
   a cheer, or three neutral beeps ([UC-0010](UC-0010-configure-app-preferences.md)). If confetti is
   enabled, System also shows it.
9. System records the completed workout ([UC-0005](UC-0005-record-a-workout.md)).
10. System shows the workout summary: kind, reps, and duration, plus active calories and
    average/maximum heart rate when a Watch tracked the workout.
11. Athlete closes the summary and returns to the presets.

## Extensions

- 3a. Athlete tries to pause or stop during the countdown:
  - 3a1. System ignores the request; the countdown can't be interrupted.
  - 3a2. Use case continues at step 4.
- 5a. Athlete pauses the workout:
  - 5a1. System freezes all times and indicates that the workout is paused.
  - 5a2. Athlete resumes the workout.
  - 5a3. System continues from the frozen times. Pause time doesn't count toward the duration.
  - 5a4. Use case continues at step 5.
- 5b. Athlete ends the workout before the duration has elapsed:
  - 5b1. System stops the workout, records it as stopped early
    ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b), and returns to the presets.
  - 5b2. Use case ends.
- 5c. The iPhone app moves to the background (e.g. the phone is locked) while the iPhone runs the workout:
  - 5c1. System pauses the workout.
  - 5c2. When the app returns to the foreground, the workout is still paused until Athlete resumes
    it, as in 5a2–5a3.
  - 5c3. Use case continues at step 5.
- 5d. The iPhone app moves to the background while a Watch owns the workout:
  - 5d1. The workout keeps running on the Watch. When the app returns, System shows the current
    times again.
  - 5d2. Use case continues at step 5.
- 5e. Athlete chose to see reps instead of the interval time ([UC-0010](UC-0010-configure-app-preferences.md)):
  - 5e1. System shows the current rep and the total reps in place of the interval time.
  - 5e2. Use case continues at step 6.
- 7a. Sound is switched off ([UC-0010](UC-0010-configure-app-preferences.md)):
  - 7a1. System gives no audible signals: no countdown beeps, interval beeps or completion sound.
    The visual signals remain.
  - 7a2. Use case continues at step 8.
- 10a. A Watch owned the workout, and its heart rate and calories haven't arrived yet:
  - 10a1. System shows placeholders and fills in the values when they arrive.
  - 10a2. Use case continues at step 11.
- 10b. No Watch tracked the workout:
  - 10b1. System shows duration and reps only, and points out that a Watch provides heart rate and calories.
  - 10b2. Use case continues at step 11.
- 10c. Health data exists for the workout:
  - 10c1. Athlete may open Apple Health from the summary.
  - 10c2. Use case continues at step 11.

## Special Requirements

- The display must not go to sleep while the workout is running.
- The app's audio mixes with other audio, such as music, instead of interrupting it.
- Smooth animations ([UC-0010](UC-0010-configure-app-preferences.md)) refresh the display at its
  refresh rate. Without them the display updates five times per second. Timing accuracy is the same
  either way, because times are derived from absolute dates.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#emom-timer)
- [UC-0002](UC-0002-run-an-amrap-workout.md) (AMRAP counterpart),
  [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md) (running it with the Watch),
  [UC-0004](UC-0004-run-a-workout-on-apple-watch.md) (Watch alone)
- Known deviations (fix candidates): early stops are not recorded today (5b); the iPhone's countdown beeps ignore Sound off (extension 7a).
