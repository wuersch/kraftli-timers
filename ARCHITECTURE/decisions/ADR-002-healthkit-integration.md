# ADR-002: HealthKit Integration with Two-Channel Watch Communication

**Status**: Accepted
**Date**: 2026-02-03

## Context

Kraftli Timers needs to save completed workouts to Apple Health so they appear in the Fitness app and contribute to Activity Rings. When an Apple Watch is available, workouts should include heart rate and calorie data from Watch sensors.

Key challenges:
- Four distinct workout scenarios depending on which device initiates and whether Watch is available
- Only Watch has sensors for heart rate and calories — iPhone-only workouts are duration-only
- HealthKit's `HKWorkoutSession` is the mechanism for keeping Watch sensors active and the app running in the background
- Both devices could potentially save to HealthKit, causing duplicates
- The Watch app may or may not be running when iPhone starts a workout

## Decision

Use a **two-channel communication architecture** between iPhone and Watch:

1. **HealthKit channel**: `HKHealthStore.startWatchApp(toHandle:)` launches the Watch app and delivers an `HKWorkoutConfiguration` to `WorkoutAppDelegate`. This channel handles workout session lifecycle.

2. **WatchConnectivity channel**: `WatchMessage` protocol messages handle timer UI synchronization (start, pause, stop, round increments) and result correlation (`WorkoutSessionEndedMessage` with HealthKit UUID).

### Shared WorkoutSessionManager

A single `WorkoutSessionManager` instance is owned by `WorkoutAppDelegate` and injected into timer views via `@Environment`. This ensures:
- Only one `HKWorkoutSession` runs at a time
- Both the delegate (iPhone-initiated) and timer views (Watch-initiated) use the same session
- Timer views check `sessionManager.sessionState` before creating sessions

### Duplicate Prevention

Each workout has exactly one HealthKit save:
- **Scenario A** (iPhone only): iPhone saves to HealthKit
- **Scenario B** (Watch only): Watch saves via `HKLiveWorkoutBuilder`
- **Scenario C** (iPhone leads): Watch runs the `HKWorkoutSession`; iPhone tracks `watchHandledWorkout = true` and skips its own HealthKit save
- **Scenario D** (Watch leads): Watch saves; sends UUID to iPhone via `WorkoutSessionEndedMessage`

### Protocol-Based Services

Both `HealthKitService` (iPhone) and `WorkoutSessionManager` (Watch) follow the protocol pattern with silent implementations for testing and previews.

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| iPhone-only HealthKit saves | Simpler, single save point | No heart rate or calorie data; defeats purpose of Watch integration |
| WorkoutKit (iOS 17+) | Higher-level API, workout plans | Less control over session lifecycle; limited to newer OS versions; primarily designed for Apple's Workout app |
| Single WatchConnectivity channel | Simpler message flow | Can't launch Watch app programmatically; no background sensor access without HKWorkoutSession |
| Always save on both devices, deduplicate later | Simpler code per-device | Complex deduplication; HealthKit doesn't expose easy duplicate detection; user sees double entries |

## Consequences

### Positive
- Watch workouts include real heart rate and calorie data from Apple's algorithms
- `HKWorkoutSession` keeps the Watch app alive in background (replaces `WKExtendedRuntimeSession`)
- Workouts appear in Apple Fitness with accurate data
- Clean separation: HealthKit channel for session lifecycle, WatchConnectivity for UI sync
- No duplicate HealthKit entries

### Negative
- Two parallel communication channels add complexity
- Timing-sensitive: Watch must be ready before WatchConnectivity messages arrive
- `startWatchApp(toHandle:)` restricted to Healthcare & Fitness App Store category
- Crash recovery is complex (stub implementation for now)
- iPhone can't verify Watch actually started the session before setting `watchHandledWorkout`

### Neutral
- Watch app must have HealthKit capability and Background Modes (Workout processing)
- Authorization prompts shown lazily on first workout, not on app launch
- Session Type set to "None" — `HKWorkoutSession` provides its own runtime

## Future Direction

1. **Scenario D mirrored UI**: Show a read-only timer on iPhone when Watch starts a workout independently
2. **Crash recovery**: Implement `HKHealthStore.recoverActiveWorkoutSession()` to recover orphaned sessions
3. **Message reliability**: Add retry/acknowledgment for critical messages (UUID correlation)
4. **Live metrics display**: Show heart rate and calories on both devices during workout
5. **Workout summaries**: Post-workout screen with heart rate zones, calories, duration breakdown
