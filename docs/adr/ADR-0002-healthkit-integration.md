# ADR-0002: Integrate Apple Health via HealthKit workout sessions on the Watch, linked to app logs by workout ID

- **Status:** implemented
- **Date:** 2026-02-03 (amended 2026-10-25 by ADR-0006; migrated 2026-10-31)
- **Deciders:** Michael Würsch

## Context and Problem Statement

Completed workouts should be saved to Apple Health, so they appear in the Fitness app and
contribute to Activity Rings. When an Apple Watch is involved, they should include heart rate and
calories from its sensors.

- There are four scenarios: iPhone only, Watch only, iPhone-started with the Watch, and Watch-started.
- Only the Watch has sensors. iPhone-only workouts can record duration only.
- `HKWorkoutSession` is what keeps the Watch's sensors active and the app running in the background.
- Both devices could save the same workout, which would create duplicates.
- The Watch app may or may not be running when the iPhone starts a workout.

Which frameworks and channels should the app use to run and record workouts in Apple Health,
without duplicates?

## Decision Drivers

- Real heart rate and calorie data whenever a Watch is involved
- The Watch app must keep running in the background during a workout
- Each workout saved to Health exactly once
- The app's own history stays the source of truth; Health holds a linked copy

## Considered Options

- iPhone-only HealthKit saves
- WorkoutKit (iOS 17+)
- A single WatchConnectivity channel
- Save on both devices and deduplicate later
- HealthKit workout sessions on the Watch, launched from the iPhone, plus WatchConnectivity for app messages

## Decision Outcome

Chosen option: **HealthKit workout sessions on the Watch, launched from the iPhone, plus
WatchConnectivity for app messages**. It is the only option that gives sensor data and background
runtime, and it allows exactly one save per workout.

- **HealthKit channel:** `HKHealthStore.startWatchApp(toHandle:)` launches the Watch app and
  delivers an `HKWorkoutConfiguration` (HIIT, indoor) to `WorkoutAppDelegate`. The Watch runs
  `HKWorkoutSession` + `HKLiveWorkoutBuilder`. A single `WorkoutSessionManager` per Watch app
  makes sure only one session runs at a time.
- **App messages:** after the workout, the Watch sends a `WorkoutSessionEndedMessage` (Health
  workout UUID, heart rate, calories, workout ID). It uses dual delivery, `sendMessage` plus
  `transferUserInfo`; the iPhone treats a repeat delivery of an equal message as harmless.
- **Correlation:** every workout has a workout ID. It becomes the `WorkoutLog.id` and the Health
  workout's `HKMetadataKeyExternalUUID`, and the Watch's message carries it, so the iPhone links the
  Health UUID to the exact log by primary key.
- **Exactly one save** (amended by ADR-0006): the device that **owns** the workout's timer state
  saves it to Health. iPhone-only workouts are saved by the iPhone, duration only. Workouts the
  Watch owns are saved by the Watch with heart rate and energy.
- **No calorie estimation on iPhone:** guessed calories would mislead, so iPhone-only workouts
  record no energy.
- **Authorization is requested lazily**, never at launch:
  - **iPhone**, at its first Health save: write workouts, read heart rate.
  - **Watch**, at every session start: write workouts, heart rate and active energy; read heart
    rate and active energy.
- **Crash recovery** (issue #49): an orphaned session recovered after a crash or watchdog kill is
  **finalized** to Health (`endCollection(at:)` + `finishWorkout()`, end = recovery time), not
  discarded. A partial workout the user earned belongs in Health, and the user can delete it there. No
  `WorkoutLog` or iPhone message is created, because the timer metadata is gone with the crash.
- **Timer sync** is no longer part of this decision. ADR-0006 replaced the WatchConnectivity timer
  events and the "pause/resume through the mirrored session" strategy described in the original
  version. The mirrored session now only carries snapshot data, and the owner pauses its own
  session as a consequence of the timer state.

### Consequences

- Good, because Watch workouts include real heart rate and calories from Apple's algorithms.
- Good, because `HKWorkoutSession` keeps the Watch app alive in the background, which replaced
  `WKExtendedRuntimeSession` for owned workouts.
- Good, because workouts appear in Fitness and count toward Activity Rings, with no duplicates.
- Bad, because two communication channels (HealthKit and WatchConnectivity) add complexity.
- Bad, because `startWatchApp(toHandle:)` is restricted to the Healthcare & Fitness App Store category.
- Bad, because iPhone-only workouts carry no heart rate or calories.
- Bad, because a crash-recovered workout lands in Health without a matching in-app log, and its
  end date is the recovery time, which can inflate its duration.
- Neutral: the Watch target needs the HealthKit capability and the "Workout processing" background
  mode. The extended runtime session type is "None".

## Pros and Cons of the Options

### iPhone-only HealthKit saves

- Good, because there is one save point and the simplest code.
- Bad, because there is no heart rate or calorie data, which defeats the Watch integration.

### WorkoutKit

- Good, because it is a higher-level API with workout plans.
- Bad, because it is designed for composing workouts for Apple's Workout app, and gives less
  control over the session lifecycle while our own timer runs.

### Single WatchConnectivity channel

- Good, because the message flow is simpler.
- Bad, because it can't launch the Watch app, and without `HKWorkoutSession` there are no sensors
  and no background runtime.

### Save on both devices, deduplicate later

- Good, because each device's code is simpler.
- Bad, because HealthKit offers no easy way to detect duplicates, so users would see double entries.

### HealthKit sessions on the Watch + WatchConnectivity

- Good, because it provides sensor data and background runtime, and allows exactly one save.
- Bad, because it uses two channels, is sensitive to timing, and is App Store category-gated.

## More Information

- Amended by [ADR-0006](ADR-0006-single-owner-timer-state.md): ownership decides the Health save,
  replacing `watchHandledWorkout`.
- Requirements this decision serves: [UC-0005](../use-cases/UC-0005-record-a-workout.md).
- Reference values:
  - Activity type: `.highIntensityIntervalTraining` for both EMOM and AMRAP, location indoor.
  - Metadata: `HKMetadataKeyExternalUUID` = workout ID, `com.kraftli.timer.kind`,
    `com.kraftli.timer.exercise`.
  - Usage descriptions: `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` on both targets.
- HealthKit needs physical devices for meaningful testing; the Simulator's support is limited.
- Future direction: an iOS 26 `HKWorkoutSession` on the iPhone could record heart rate from
  AirPods or a BLE strap for iPhone-owned workouts (see ADR-0006).
