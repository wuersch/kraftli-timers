# HealthKit & WorkoutKit Integration

This document describes how Kraftli Timers integrates with Apple's health and fitness frameworks to record workouts and capture metrics like heart rate and calories.

> **Audience**: Part 1 is written for discussion with non-technical stakeholders. Part 2 contains technical implementation details.

---

# Part 1: User Experience & Scenarios

## 1.1 What This Integration Enables

When you complete a workout in Kraftli Timers, the app can:

1. **Save your workout to Apple Health** — Your EMOM or AMRAP session appears in the Health app and Fitness app alongside workouts from other apps
2. **Capture heart rate and calories** — If your Apple Watch is involved, the workout includes real heart rate data and accurate calorie calculations (iPhone-only workouts record duration only)
3. **Contribute to your Activity Rings** — Exercise minutes count toward closing your rings; calories require Watch involvement
4. **Enable health insurance rewards** — Many insurance apps (e.g., Vitality, AOK Bonus) reward workouts logged to Apple Health

### Data Ownership

Kraftli Timers keeps its own workout history (the Stats tab). HealthKit is a *copy* for system-wide visibility, not the source of truth.

Both records are linked:
- Our workout stores the HealthKit workout's ID (so we know it was synced)
- The HealthKit entry stores our workout's ID (so we can match them later if needed)

This means: if you delete a workout in Kraftli Timers, we can also remove it from Health. If you delete it in the Health app, our record stays intact.

## 1.2 What is HealthKit vs WorkoutKit?

**HealthKit** is Apple's central health database on your iPhone. Think of it as a journal where all your health apps can write entries (steps, workouts, sleep, etc.) and read each other's data (with your permission). HealthKit stores data but doesn't run workouts.

**WorkoutKit** is a watchOS framework that *runs* workouts on Apple Watch. It keeps the screen awake, enables reliable haptic feedback, and streams live sensor data (heart rate, calories). When a WorkoutKit session ends, it automatically saves the workout to HealthKit.

**In simple terms**: WorkoutKit is the athlete, HealthKit is the record book.

## 1.3 Three Workout Scenarios

The app supports three ways to work out, each with different capabilities:

### Scenario A: iPhone Only

**Setup**: User starts timer on iPhone. Watch app is not running (or no Watch paired).

**What happens**:
- Timer runs on iPhone as normal
- When workout completes, iPhone writes a workout record to HealthKit
- Duration is recorded; calories are either omitted or rough-estimated by us
- No heart rate data (Watch sensors not involved)

**User experience**: Workout appears in Health app with duration only. No heart rate chart, no calories.

> **Design decision**: We do not estimate calories ourselves. Only Watch workout sessions provide accurate calorie data via Apple's algorithms. iPhone-only workouts record duration and activity type only.

---

### Scenario B: Watch Only

**Setup**: User starts timer directly on Apple Watch. iPhone might be at home or in another room.

**What happens**:
- Watch starts a workout session (WorkoutKit/HKWorkoutSession)
- Heart rate sensor activates, calories are tracked in real-time
- Timer runs independently on Watch
- When workout completes, Watch saves to HealthKit
- Data syncs to iPhone's Health app later

**User experience**: Full workout with heart rate and accurate calories, even without iPhone nearby.

---

### Scenario C: Both Devices (iPhone Leads)

**Setup**: User starts timer on iPhone. Watch app is open and reachable.

**What happens**:
- iPhone detects Watch is reachable
- iPhone sends "start workout session" message to Watch
- Watch starts workout session (sensors activate)
- iPhone starts timer and sends "start mirrored timer" to Watch
- Both devices show the timer; Watch collects heart rate
- When timer ends, Watch saves workout to HealthKit
- Our WorkoutLog stores a reference to the HealthKit entry

**User experience**: Timer visible on both screens. Workout includes heart rate and accurate calories.

---

### Scenario D: Both Devices (Watch Leads) — Future

> This scenario is planned for a future update.

**Setup**: User starts timer on Watch. iPhone app is running.

**What happens**:
- Watch sends "start timer" message to iPhone
- iPhone starts mirrored timer
- Otherwise same as Scenario C

**User experience**: Same as C, but initiated from Watch.

## 1.4 How the App Decides Which Mode to Use

When the user taps "Start" on iPhone:

```
Is Watch app reachable?
├─ YES → Scenario C (both devices, full metrics)
└─ NO  → Scenario A (iPhone only, estimated calories)
```

The decision is made once at workout start and doesn't change mid-workout. This keeps things predictable — if Watch becomes unreachable during a workout, we don't try to reconnect.

When the user taps "Start" on Watch:

```
Always → Scenario B (Watch session with full metrics)
```

Watch workouts always use full sensor capabilities since the Watch has the hardware.

## 1.5 Permission Prompts

HealthKit requires explicit user permission. The app asks for permission at appropriate moments:

### On iPhone

**When**: First time the user completes a workout (just before saving to Health).

**What we request**:
- Write workouts to Health
- Read heart rate data (for future summary screens)

**If denied**: Workout is still saved locally in the app. A subtle message indicates Health sync was skipped. User can enable later in Settings.

### On Apple Watch

**When**: First time the user starts a workout on Watch.

**What we request**:
- Write workouts to Health
- Read/write heart rate
- Read/write active energy (calories)

**If denied**: Workout runs normally but isn't saved to Health. Local app history still works.

### Important Notes

- Each device prompts independently — user might grant on iPhone but deny on Watch (or vice versa)
- Permissions can be changed anytime in iOS Settings → Health → Kraftli Timers
- We never ask on app launch; only when the feature is actually used

## 1.6 Edge Cases and Failure Handling

### Watch becomes unreachable during workout

- **Behavior**: iPhone continues timer normally. Watch may have partial heart rate data.
- **Result**: Workout is saved with whatever data was collected before disconnect.
- **User sees**: Normal workout completion. Possibly incomplete HR data in Health app.

### HealthKit permission denied

- **Behavior**: Workout completes normally. Not saved to Health.
- **Result**: Workout exists in Kraftli Timers history but not in Health app.
- **User sees**: Optional subtle indicator that Health sync was skipped.

### HealthKit save fails (rare)

- **Behavior**: Error is logged. Workout remains in local history.
- **Result**: User's workout is not lost, just not in Health.
- **User sees**: Nothing (silent failure). Could show indicator in future.

### User deletes workout from Health app

- **Behavior**: Our local WorkoutLog remains unchanged.
- **Result**: Workout exists in Kraftli Timers but not Health.
- **User sees**: Normal. Our app is the source of truth for our history.

### Watch app not installed

- **Behavior**: Same as Scenario A (iPhone only).
- **Result**: Workouts saved without heart rate.
- **User sees**: Normal experience. No error messages.

## 1.7 What's NOT Included (Phase 1)

To keep the first release focused and reliable, these features are deferred:

| Feature | Reason for Deferral |
|---------|---------------------|
| **Live heart rate display** | Requires flawless Watch-iPhone communication. If it glitches, users notice immediately and get frustrated. |
| **Post-workout summary screen** | Needs UX design work (animations, layout, swipe-to-dismiss). |
| **Programs integration** | Single HealthKit session spanning multiple exercises adds complexity. |

Phase 1 focuses on reliably getting workout data into Health. Live display and summaries come later once the foundation is solid.

---

# Part 2: Technical Appendix

> This section is for implementation reference.

## 2.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iPhone                                   │
│  ┌──────────────┐    ┌───────────────────┐    ┌──────────────┐ │
│  │ Timer View   │───▶│ CountdownCoordinator│───▶│HealthKit    │ │
│  │ (EMOM/AMRAP) │    │ onCountdownComplete │    │Service (new)│ │
│  └──────────────┘    └───────────────────┘    └──────────────┘ │
│         │                                            │          │
│         │ WatchConnectivity                          │          │
│         ▼                                            ▼          │
│  ┌──────────────┐                            ┌──────────────┐   │
│  │WatchConnectivity│                          │  HealthKit   │   │
│  │   Service    │                            │   (System)   │   │
│  └──────────────┘                            └──────────────┘   │
└─────────┬───────────────────────────────────────────┬───────────┘
          │                                           │
          │ Messages                                  │ Sync
          ▼                                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Apple Watch                               │
│  ┌──────────────┐    ┌───────────────────┐    ┌──────────────┐ │
│  │ Timer View   │───▶│WatchCountdown     │───▶│WorkoutSession│ │
│  │              │    │   Coordinator     │    │Manager (new) │ │
│  └──────────────┘    └───────────────────┘    └──────────────┘ │
│                                                      │          │
│                                                      ▼          │
│                                               ┌──────────────┐  │
│                                               │  HealthKit   │  │
│                                               │   (System)   │  │
│                                               └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 2.2 Data Flow: Scenario C (Both Devices)

```
1. User taps Start on iPhone
2. iPhone checks WCSession.isReachable
3. iPhone sends WatchMessage.startWorkoutSession(presetId, scheduledStartTime)
4. Watch receives message, starts HKWorkoutSession/WorkoutKit session
5. Watch sends acknowledgment
6. iPhone starts CountdownCoordinator
7. iPhone sends WatchMessage.startTimer(presetId, scheduledStartTime)
8. Both devices count down and start timers in sync
9. Watch collects HR samples throughout workout
10. User completes workout (or timer ends)
11. iPhone sends WatchMessage.endWorkoutSession
12. Watch ends HKWorkoutSession → automatically saves to HealthKit
13. Watch sends WatchMessage.workoutSessionEnded(hkWorkoutUUID)
14. iPhone stores hkWorkoutUUID in WorkoutLog
```

## 2.3 Existing Integration Points

### CountdownCoordinator (iOS)

Already has `onCountdownComplete` hook — perfect for triggering "start workout session" on Watch.

```swift
// Current hook in CountdownCoordinator.swift:44
var onCountdownComplete: (() -> Void)?
```

### WatchConnectivityService

Already supports bidirectional messaging. Need to add new message types:

```swift
enum WatchMessage {
    // Existing
    case startTimer(presetId: UUID, scheduledStartTime: Date)
    case pauseTimer
    case resumeTimer
    case stopTimer

    // New for HealthKit
    case startWorkoutSession(presetId: UUID, scheduledStartTime: Date)
    case endWorkoutSession
    case workoutSessionEnded(hkWorkoutUUID: UUID?)
    case workoutSessionFailed(error: String)
}
```

### WKExtendedRuntimeSession (Watch)

Currently used for keeping Watch app alive during workouts. **Question**: Can `HKWorkoutSession` replace this, or do we need both?

**Answer**: `HKWorkoutSession` provides similar extended runtime privileges during active workouts. We can likely replace `WKExtendedRuntimeSession` with `HKWorkoutSession` for workout scenarios, but should verify behavior when workout is paused.

### WorkoutLog Model

Add field for HealthKit correlation:

```swift
// In WorkoutLog model
var healthKitWorkoutUUID: UUID?
```

## 2.4 New Components to Create

### iPhone: HealthKitService

```swift
/// Manages HealthKit authorization and workout writing on iPhone.
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    /// Request authorization for workout types we need
    func requestAuthorization() async throws

    /// Write a workout directly (iPhone-only scenario)
    /// Note: No calorie parameter — we don't estimate. Only Watch provides calories.
    func saveWorkout(
        type: HKWorkoutActivityType,
        start: Date,
        end: Date,
        metadata: [String: Any]?
    ) async throws -> HKWorkout

    /// Check if HealthKit is available
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
}
```

### Watch: WorkoutSessionManager

```swift
/// Manages HKWorkoutSession lifecycle on Apple Watch.
@Observable
final class WorkoutSessionManager {
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// Start a workout session (called when iPhone requests or Watch initiates)
    func startSession(activityType: HKWorkoutActivityType) async throws

    /// End the session and save to HealthKit
    func endSession() async throws -> UUID?  // Returns HKWorkout UUID

    /// Pause/resume for timer pause states
    func pause()
    func resume()

    /// Current heart rate (for future live display)
    var currentHeartRate: Double?

    /// Current active calories
    var activeCalories: Double?
}
```

## 2.5 Implementation Phases

### Phase 1A: iPhone-Only Path (Foundation)

1. Create `HealthKitService` on iPhone
2. Add HealthKit capability to project
3. Add permission request flow
4. Save workout to HealthKit when timer completes (no Watch involvement)
5. Store `healthKitWorkoutUUID` in `WorkoutLog`
6. Test: Complete workout on iPhone → appears in Health app

### Phase 1B: Watch Workout Session

1. Create `WorkoutSessionManager` on Watch
2. Add HealthKit capability to Watch target
3. Implement `HKWorkoutSession` lifecycle
4. Handle Watch-only workouts (Scenario B)
5. Test: Complete workout on Watch → appears in Health app with HR

### Phase 1C: Coordinated Sessions (Both Devices)

1. Add new `WatchMessage` types for workout session control
2. iPhone detects Watch reachability at workout start
3. iPhone sends start/end workout session messages
4. Watch starts `HKWorkoutSession` when requested
5. Watch sends back `hkWorkoutUUID` when session ends
6. iPhone stores UUID in `WorkoutLog`
7. Test: Start on iPhone with Watch → full metrics in Health

### Phase 1D: Edge Cases & Polish

1. Handle permission denied gracefully
2. Handle Watch disconnect mid-workout
3. Handle HealthKit save failures
4. Add subtle UI indicators for sync status (optional)
5. Verify `WKExtendedRuntimeSession` replacement behavior

## 2.6 Key Technical Considerations

### HKWorkoutActivityType Mapping

```swift
// Map our timer types to HealthKit activity types
extension TimerKind {
    var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .emom, .amrap:
            return .highIntensityIntervalTraining  // HIIT is closest match
        }
    }
}
```

### Metadata Keys

```swift
// Standard Apple key for correlation
let metadata: [String: Any] = [
    HKMetadataKeyExternalUUID: workoutLog.id.uuidString,
    // Custom keys (optional)
    "com.kraftli.timer.kind": preset.kind.rawValue,
    "com.kraftli.timer.intervals": preset.intervals
]
```

### Calorie Handling (iPhone-Only)

**Decision**: We do not estimate calories ourselves.

When Watch isn't involved, workouts are saved without calorie data. Only Watch workout sessions (via `HKLiveWorkoutBuilder`) provide accurate, Apple-calculated calories based on heart rate and user profile.

Rationale: Guessed calorie data is misleading. Users who want calorie tracking should use the Watch app.

### Authorization Flow

```swift
// Types to request on iPhone
let typesToWrite: Set<HKSampleType> = [
    HKObjectType.workoutType()
]

let typesToRead: Set<HKObjectType> = [
    HKObjectType.quantityType(forIdentifier: .heartRate)!
]

// Types to request on Watch
let watchTypesToWrite: Set<HKSampleType> = [
    HKObjectType.workoutType(),
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
]
```

### Testing Considerations

- Test on physical devices (Simulator doesn't support HealthKit well)
- Test permission flows: grant, deny, revoke mid-use
- Test Watch connectivity edge cases
- Verify workouts appear correctly in Health and Fitness apps
- Check Activity Ring contribution

## 2.7 Open Questions

1. **WKExtendedRuntimeSession replacement**: Need to verify if `HKWorkoutSession` alone keeps app alive during paused states, or if we need both.

2. **Workout pause behavior**: When user pauses timer, should we pause `HKWorkoutSession`? This affects how the workout appears in Health (paused time included or not).

3. **Multiple workouts same day**: If user does 3 EMOM sessions, should they be 3 separate workouts or one combined? Current design: 3 separate (simpler, matches user expectation).

---

## References

- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [WorkoutKit Documentation](https://developer.apple.com/documentation/workoutkit)
- [HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [HKLiveWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder)
