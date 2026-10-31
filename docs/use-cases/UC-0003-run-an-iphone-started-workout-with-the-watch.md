# UC-0003: Run an iPhone-started workout together with the Watch

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete wearing an Apple Watch, I want a workout I start on the iPhone to run on
  my Watch as well, so that heart rate and calories are captured and I can follow and control the
  workout from whichever device is closer.
- **Scope:** Kraftli Timers (iPhone app + Watch app)
- **Level:** user-goal

## Stakeholders and Interests

- Athlete: both devices always show the same time; a control used on either device takes effect
  immediately; nothing counted gets lost when the devices lose contact.
- Athlete's Apple Health record: each workout appears exactly once, with heart rate and calories
  whenever the Watch tracked it.

## Preconditions

- The athlete has started an EMOM or AMRAP workout on the iPhone ([UC-0001](UC-0001-run-an-emom-workout.md),
  [UC-0002](UC-0002-run-an-amrap-workout.md)).
- An Apple Watch is paired with the iPhone and has the Kraftli Timers Watch app installed.

## Success Guarantee

- The Watch ran the workout and tracked heart rate and calories. The iPhone followed it, and both
  devices showed the same remaining time throughout.
- Every pause, resume, counted round and stop, made on either device, took effect on both.
- The workout is recorded once in the workout history and once in Apple Health, with heart rate and
  calories ([UC-0005](UC-0005-record-a-workout.md)).

## Minimal Guarantee

- Exactly one device runs the workout at any time. The athlete is told when that device is the
  iPhone instead of the Watch.
- No AMRAP round counted on either device is lost.

## Trigger

The athlete starts a workout on the iPhone while a paired Watch has the app installed.

## Main Success Scenario

1. System indicates on the iPhone that the workout is starting on the Watch, and opens the Watch app.
2. The Watch app confirms that it runs the workout. Confirmation usually takes under a second when
   the Watch app is already open, and a few seconds when it has to launch.
3. Both devices count down to the same start instant and start the workout at that instant.
4. The Watch tracks heart rate and calories for the whole workout.
5. Both devices show the same remaining time, interval, reps or rounds.
6. Athlete pauses, resumes, or counts a round on either device.
7. System applies the action immediately on that device and on the other, as of the moment the athlete acted.
   Steps 6–7 repeat as needed.
8. The duration elapses, and both devices show the workout as done.
9. System records the workout ([UC-0005](UC-0005-record-a-workout.md)). The iPhone shows
   the summary with heart rate and calories from the Watch.

## Extensions

- 1a. The iPhone can't open the Watch app, or the Watch doesn't confirm within 5 seconds:
  - 1a1. The iPhone runs the workout itself, and System tells the athlete: "Watch not available —
    running on iPhone".
  - 1a2. No heart rate or calories are tracked.
  - 1a3. Use case continues at step 3.
- 1b. The Watch app starts after the iPhone has already taken over (1a):
  - 1b1. The Watch follows the iPhone's workout and can control it, but doesn't track heart rate
    or calories, and doesn't save to Apple Health.
  - 1b2. Use case continues at step 5.
- 1c. Athlete ends the workout while it is still starting on the Watch:
  - 1c1. System cancels the start. If the Watch confirms afterwards, it ends the workout immediately.
  - 1c2. Use case ends.
- 2a. The Watch has received a start request that is older than 10 seconds:
  - 2a1. The Watch ignores it. The iPhone runs the workout itself, as in 1a.
  - 2a2. Use case continues at step 3.
- 2b. The Watch is waiting to start, but no device has taken the workout within 10 seconds:
  - 2b1. The Watch abandons the start. The iPhone runs the workout itself, as in 1a.
  - 2b2. Use case continues at step 3.
- 6a. The devices are out of contact when the athlete acts:
  - 6a1. System applies the action immediately on the device in hand.
  - 6a2. The iPhone indicates that some changes haven't reached the Watch yet. This applies while
    any change is unconfirmed, including the brief moment before confirmation when in contact.
  - 6a3. Once back in contact, the changes are delivered in the order they were made.
  - 6a4. Use case continues at step 7.
- 6b. While out of contact, the athlete paused or resumed on both devices, and the states disagree:
  - 6b1. The state of the device running the workout wins. The other device adopts it, and System
    shows "Synced with Watch" on the iPhone, or "Synced with iPhone" on the Watch.
  - 6b2. Use case continues at step 5.
- 6c. While out of contact, rounds were counted on both devices:
  - 6c1. System adds them up.
  - 6c2. Use case continues at step 5.
- 6d. Athlete ends the workout on either device before the duration has elapsed:
  - 6d1. System stops the workout on both devices, records it as stopped early
    ([UC-0005](UC-0005-record-a-workout.md) extensions 1a–1b), and both return to their preset lists.
  - 6d2. Use case ends.
- 6e. The iPhone app goes to the background or the phone is locked:
  - 6e1. The workout keeps running on the Watch, and the iPhone catches up when it returns.
  - 6e2. Use case continues at step 5.
- 8a. Contact is lost and never comes back before the end:
  - 8a1. Each device shows completion when the time runs out.
  - 8a2. The iPhone records the workout from what it last knew.
  - 8a3. Heart rate and calories reach the iPhone only once the devices are back in contact. If
    the Watch never reports, they are lost.
  - 8a4. Use case continues at step 9.

## Special Requirements

- Devices must agree on the displayed time within tens of milliseconds, the accuracy of the
  synced device clocks. Pauses, resumes and reconnects must not cause drift.
- A change made while out of contact must be delivered once contact returns, even if the app was
  relaunched meanwhile.

## Related Information

- Architecture: [ADR-0006](../adr/ADR-0006-single-owner-timer-state.md) (one device owns the
  workout), [ADR-0007](../adr/ADR-0007-optimistic-viewer-control.md) (controls on the following device)
- Interaction design: [ui-spec.md](ui-spec.md#watch-sync-indicators)
- Known deviation (fix candidate): the Watch doesn't show "Synced with iPhone" (extension 6b1).
- Out of scope (backlog): the iPhone following a workout started on the Watch
  ([UC-0004](UC-0004-run-a-workout-on-apple-watch.md)).
