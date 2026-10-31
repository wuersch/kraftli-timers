# UC-0004: Run a workout on the Apple Watch alone

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to start and run an EMOM or AMRAP workout from my wrist without
  my iPhone, while seeing my heart rate and calories live.
- **Scope:** Kraftli Timers (Watch app)
- **Level:** user-goal

## Preconditions

- The Watch app has at least one preset: synced from the iPhone, or created on the Watch
  ([UC-0006](UC-0006-manage-timer-presets.md)).

## Success Guarantee

- The workout ran to the end of its duration on the Watch, with heart rate and active calories tracked.
- The workout is recorded in the history and in Apple Health ([UC-0005](UC-0005-record-a-workout.md)).

## Minimal Guarantee

- A workout ended early is recorded as stopped early once it had at least 1 minute of active time,
  otherwise not at all ([UC-0005](UC-0005-record-a-workout.md)).

## Trigger

The athlete starts a preset on the Watch.

## Main Success Scenario

1. Athlete starts a preset on the Watch.
2. System runs the workout on the Watch and begins tracking heart rate and active calories.
3. System counts down 3 seconds to the start, silently.
4. System starts the workout. It continuously shows the total time remaining and the live heart
   rate and active calories. For EMOM it also shows the time remaining in the interval and the
   current rep. For AMRAP it shows the rounds counted.
5. For EMOM, System highlights the last 3 seconds of each interval. For AMRAP, Athlete counts each
   completed round, and System adds it to the total.
6. When the duration has elapsed, System marks the workout as done.
7. System records the workout ([UC-0005](UC-0005-record-a-workout.md)).
8. Athlete ends the session, and the Watch returns to the presets.

## Extensions

- 2a. Access to Apple Health was denied on the Watch:
  - 2a1. The workout runs without heart rate and calories and isn't saved to Apple Health
    ([UC-0005](UC-0005-record-a-workout.md) extension 3a).
  - 2a2. Use case continues at step 3.
- 3a. Athlete dismisses the countdown:
  - 3a1. System hides the countdown, but the workout still starts at the planned instant.
  - 3a2. Use case continues at step 4.
- 4a. Athlete pauses the workout:
  - 4a1. System freezes the time and pauses heart-rate and calorie tracking.
  - 4a2. Athlete resumes; System continues from the frozen time and returns to the workout metrics.
  - 4a3. Use case continues at step 4.
- 4b. Athlete ends the workout before the duration has elapsed:
  - 4b1. System stops the workout and records it as stopped early
    ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b).
  - 4b2. Use case continues at step 8.
- 4c. Heart rate or calories aren't available yet:
  - 4c1. System shows placeholders until values arrive.
  - 4c2. Use case continues at step 5.
- 5a. Athlete tries to count an AMRAP round while the workout is paused, counting down, or done:
  - 5a1. System ignores it.
  - 5a2. Use case continues at step 5.

## Special Requirements

- The Watch gives no sound or haptic signals during a workout. All feedback is visual. Haptics were
  tried and fired unreliably or late, which is worse than none for interval pacing.
- The workout keeps running, and tracking continues, while the wrist is lowered or the display is off.
- The workout doesn't depend on the iPhone being reachable. Its history entry reaches the iPhone
  through iCloud.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#watch-app)
- [UC-0003](UC-0003-run-an-iphone-started-workout-with-the-watch.md) covers workouts started on the iPhone.
- Out of scope (backlog): the iPhone following a workout started on the Watch
  ([backlog](../backlog.md)).
