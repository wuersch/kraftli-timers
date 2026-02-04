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

**HealthKit** is Apple's central health database on your iPhone. Think of it as a journal where all your health apps can write entries (steps, workouts, sleep, etc.) and read each other's data (with your permission). HealthKit also provides the APIs to *run* workout sessions on Apple Watch (`HKWorkoutSession`), which keeps sensors active and the screen awake.

**WorkoutKit** is a separate framework for *composing structured workouts* (intervals, goals, alerts) that sync to Apple's built-in Workout app. Users then start these workouts from the Workout app on their Watch. WorkoutKit is **not** what we use for real-time session control.

**In simple terms**: HealthKit runs and records workouts. WorkoutKit composes workout plans for Apple's Workout app.

> **For Kraftli Timers**: We use **HealthKit** (`HKWorkoutSession`, `HKLiveWorkoutBuilder`) directly, not WorkoutKit. This gives us full control over the workout lifecycle while our timer runs.

## 1.3 Three Workout Scenarios

The app supports three ways to work out, each with different capabilities:

### Scenario A: iPhone Only

**Setup**: User starts timer on iPhone. Watch app is not running (or no Watch paired).

**What happens**:
- Timer runs on iPhone as normal
- When workout completes, iPhone writes a workout record to HealthKit
- Duration is recorded; no calorie data (Watch sensors not involved)
- No heart rate data (Watch sensors not involved)

**User experience**: Workout appears in Health app with duration only. No heart rate chart, no calories.

> **Design decision**: We do not estimate calories ourselves. Only Watch workout sessions provide accurate calorie data via Apple's algorithms. iPhone-only workouts record duration and activity type only.

---

### Scenario B: Watch Only

**Setup**: User starts timer directly on Apple Watch. iPhone might be at home or in another room.

**What happens**:
- Watch starts a workout session (`HKWorkoutSession`)
- Heart rate sensor activates, calories are tracked in real-time
- Timer runs independently on Watch
- When workout completes, Watch saves to HealthKit
- Data syncs to iPhone's Health app later

**User experience**: Full workout with heart rate and accurate calories, even without iPhone nearby.

---

### Scenario C: Both Devices (iPhone Leads)

**Setup**: User starts timer on iPhone. Watch app is installed.

**What happens**:
- iPhone calls `healthStore.startWatchApp(toHandle: configuration)`
- watchOS automatically launches/wakes our Watch app
- Watch receives the configuration and starts `HKWorkoutSession` (sensors activate)
- Watch enables **mirrored session** so iPhone can track state
- iPhone starts timer and sends "start mirrored timer" via WatchConnectivity
- Both devices show the timer; Watch collects heart rate
- When timer ends, Watch saves workout to HealthKit
- Our WorkoutLog stores a reference to the HealthKit entry

**User experience**: Timer visible on both screens. Workout includes heart rate and accurate calories.

> **Key insight**: The system handles launching the Watch app automatically — no explicit WatchConnectivity message needed to start the workout session. This is the same mechanism Apple Fitness uses.

---

### Scenario D: Both Devices (Watch Leads)

**Setup**: User starts timer on Watch. iPhone app may or may not be running.

**What happens**:
- Watch starts `HKWorkoutSession` (sensors activate)
- Watch calls `startMirroringToCompanionDevice()` to enable mirrored session
- If iPhone app is running: iPhone receives mirrored session automatically via `setMirroringStartHandler`
- Watch sends timer context (preset ID, interval) via WatchConnectivity or `sendToRemoteWorkoutSession(data:)`
- iPhone starts mirrored timer display (if running)
- Both devices show the timer; Watch collects heart rate
- When timer ends, Watch saves workout to HealthKit

**User experience**: Start on Watch, optionally see timer on iPhone too. Full heart rate and calories regardless of iPhone state.

> **Key insight**: With mirrored sessions, iPhone automatically knows when Watch starts a workout — no explicit "start" message needed. We only send timer-specific context (which preset, current interval).

## 1.4 How the App Decides Which Mode to Use

When the user taps "Start" on iPhone:

```
Is Watch paired and Watch app installed?
├─ YES → Scenario C (both devices, full metrics)
│        iPhone calls startWatchApp() — system launches Watch app automatically
└─ NO  → Scenario A (iPhone only, duration only)
```

The decision is made once at workout start and doesn't change mid-workout. This keeps things predictable — if Watch becomes unreachable during a workout, we don't try to reconnect.

> **Note**: We check for Watch app installation, not "reachability". The `startWatchApp(toHandle:)` API handles waking the Watch even if it's not currently active.

When the user taps "Start" on Watch:

```
Is iPhone app running and reachable?
├─ YES → Scenario D (both devices, Watch leads, full metrics)
│        iPhone receives mirrored session automatically
└─ NO  → Scenario B (Watch only, full metrics)
```

Watch workouts always use full sensor capabilities since the Watch has the hardware. The difference is whether iPhone also displays the timer.

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
│         │                              startWatchApp │          │
│         │ WatchConnectivity              (system)    │          │
│         │ (timer sync only)                          │          │
│         ▼                                            ▼          │
│  ┌──────────────┐                            ┌──────────────┐   │
│  │WatchConnectivity│                          │  HealthKit   │   │
│  │   Service    │                            │   (System)   │   │
│  └──────────────┘                            └──────────────┘   │
└─────────┬───────────────────────────────────────────┬───────────┘
          │                                           │
          │ Timer messages                            │ Mirrored session
          ▼                                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Apple Watch                               │
│                                                                  │
│  ┌──────────────┐    Receives HKWorkoutConfiguration via        │
│  │   App        │    WKApplicationDelegate.handle(_:)           │
│  │  Delegate    │─────────────────────────────────────────┐     │
│  └──────────────┘                                         │     │
│         │                                                 ▼     │
│         ▼                                         ┌──────────┐  │
│  ┌──────────────┐    ┌───────────────────┐       │Workout   │  │
│  │ Timer View   │───▶│WatchCountdown     │──────▶│Session   │  │
│  │              │    │   Coordinator     │       │Manager   │  │
│  └──────────────┘    └───────────────────┘       └──────────┘  │
│                                                        │        │
│                                                        ▼        │
│                                               ┌──────────────┐  │
│                                               │  HealthKit   │  │
│                                               │   (System)   │  │
│                                               └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Key points:**
- This diagram shows the iPhone-initiated flow (Scenario C). For Watch-initiated (Scenario D), the Watch creates its own configuration without `startWatchApp`.
- Workout session start uses `HKHealthStore.startWatchApp(toHandle:)` — a HealthKit API, not WatchConnectivity
- watchOS automatically launches the Watch app and delivers the configuration to `WKApplicationDelegate`
- WatchConnectivity is still used for timer synchronization (pause, resume, skip, interval changes)
- Mirrored sessions (watchOS 10+) keep both devices in sync for workout state

## 2.2 Data Flow: Scenario C (Both Devices)

```
1. User taps Start on iPhone
2. iPhone creates HKWorkoutConfiguration (activityType: .highIntensityIntervalTraining)
3. iPhone calls healthStore.startWatchApp(toHandle: configuration)
4. watchOS launches/wakes our Watch app automatically
5. Watch's WKApplicationDelegate.handle(_:) receives the configuration
6. Watch starts HKWorkoutSession with the configuration
7. Watch calls session.startMirroringToCompanionDevice() (enables mirrored session)
8. iPhone receives mirrored session via healthStore.setMirroringStartHandler
9. iPhone starts CountdownCoordinator (can proceed once mirrored session is received in step 8)
10. iPhone sends WatchMessage.startTimer(presetId, scheduledStartTime) via WatchConnectivity
11. Both devices count down and start timers in sync
12. Watch collects HR samples throughout workout (via HKLiveWorkoutBuilder)
13. User completes workout (or timer ends)
14. iPhone sends WatchMessage.endWorkoutSession via WatchConnectivity
15. Watch ends HKWorkoutSession → builder.finishWorkout() saves to HealthKit
16. Watch sends WatchMessage.workoutSessionEnded(hkWorkoutUUID) via WatchConnectivity
17. iPhone stores hkWorkoutUUID in WorkoutLog

**Alternative: User ends workout on Watch**

If the user taps "End" on Watch instead of iPhone completing the timer:
- Watch ends `HKWorkoutSession` → `builder.finishWorkout()` saves to HealthKit
- Watch sends `WatchMessage.workoutSessionEnded(hkWorkoutUUID)` to iPhone
- iPhone receives the UUID and stores it in `WorkoutLog`
- iPhone stops timer display (if still running)
```

**What uses HealthKit APIs (system-managed):**
- Steps 3-8: Workout session start and mirroring

**What uses WatchConnectivity (our code):**
- Steps 10, 14, 16: Timer sync and workout end coordination

## 2.2b Data Flow: Scenario D (Watch Leads)

```
1. User taps Start on Watch
2. Watch creates HKWorkoutConfiguration (activityType: .highIntensityIntervalTraining)
3. Watch starts HKWorkoutSession with the configuration
4. Watch calls session.startMirroringToCompanionDevice() (enables mirrored session)
5. Watch starts WatchCountdownCoordinator (timer begins)
6. Watch sends WatchMessage.timerStarted(presetId, scheduledStartTime) via WatchConnectivity
7. IF iPhone app is running and reachable:
   - iPhone receives mirrored session via healthStore.setMirroringStartHandler
   - iPhone receives timer message and starts mirrored CountdownCoordinator
   - Both devices show the timer in sync
8. Watch collects HR samples throughout workout (via HKLiveWorkoutBuilder)
9. User completes workout (or timer ends)
10. Watch ends HKWorkoutSession → builder.finishWorkout() saves to HealthKit
11. Watch sends WatchMessage.workoutSessionEnded(hkWorkoutUUID) via WatchConnectivity
12. IF iPhone received the workout:
    - iPhone stores hkWorkoutUUID in WorkoutLog
```

**Key differences from Scenario C:**
- No `startWatchApp(toHandle:)` — Watch initiates directly
- No `WKApplicationDelegate.handle(_:)` — Watch creates its own configuration
- iPhone involvement is opportunistic — workout succeeds regardless of iPhone state
- Timer context sent Watch → iPhone (reverse of Scenario C)

**What uses HealthKit APIs (system-managed):**
- Steps 3-4: Workout session start and mirroring

**What uses WatchConnectivity (our code):**
- Steps 6, 11: Timer sync and workout completion notification

## 2.3 Existing Integration Points

### CountdownCoordinator (iOS)

Already has `onCountdownComplete` hook — we'll use this to trigger `startWatchApp(toHandle:)`.

```swift
// Current hook in CountdownCoordinator.swift:44
var onCountdownComplete: (() -> Void)?
```

### WatchConnectivityService

Already supports bidirectional messaging. **Important clarification**: WatchConnectivity is **not** used to start workout sessions — that's handled by `HKHealthStore.startWatchApp(toHandle:)`.

WatchConnectivity is used for:
- Timer synchronization (start, pause, resume, stop, interval changes)
- Sending `hkWorkoutUUID` back to iPhone after workout ends
- Any custom app data during the workout

```swift
// Target state after implementation:
enum WatchMessage {
    // Timer synchronization (iPhone ↔ Watch)
    case startTimer(presetId: UUID, scheduledStartTime: Date)
    case pauseTimer
    case resumeTimer
    case stopTimer

    // Watch-initiated timer (Watch → iPhone, Scenario D)
    case timerStarted(presetId: UUID, scheduledStartTime: Date)

    // Workout session coordination
    case endWorkoutSession                          // iPhone → Watch
    case workoutSessionEnded(hkWorkoutUUID: UUID?)  // Watch → iPhone
    case workoutSessionFailed(error: String)        // Watch → iPhone
}
```

> **Note**: `startTimer` (iPhone → Watch) vs `timerStarted` (Watch → iPhone) — different directions, same data.

### WKExtendedRuntimeSession (Watch)

Currently used for keeping Watch app alive during workouts. **Question**: Can `HKWorkoutSession` replace this, or do we need both?

**Answer**: `HKWorkoutSession` provides similar extended runtime privileges during active workouts. We can replace `WKExtendedRuntimeSession` with `HKWorkoutSession` for workout scenarios. The workout session keeps the app alive as long as the session is running.

### WorkoutLog Model

Add field for HealthKit correlation:

```swift
// In WorkoutLog model
var healthKitWorkoutUUID: UUID?
```

## 2.4 New Components to Create

### iPhone: HealthKitService

```swift
/// Manages HealthKit authorization, workout writing, and Watch app launching on iPhone.
final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    /// Mirrored session from Watch (set via setMirroringStartHandler)
    private(set) var mirroredSession: HKWorkoutSession?

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

    /// Start a workout on Apple Watch from iPhone (Scenario C)
    /// This launches our Watch app and sends the configuration.
    func startWorkoutOnWatch(activityType: HKWorkoutActivityType) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor  // Most HIIT workouts are indoor

        try await healthStore.startWatchApp(toHandle: configuration)
    }

    /// Set up handler to receive mirrored session from Watch
    func setupMirroringHandler() {
        healthStore.setMirroringStartHandler { [weak self] session in
            self?.mirroredSession = session
            // Now iPhone has a reference to the Watch's workout session
        }
    }

    /// Check if HealthKit is available
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Check if Watch app can be started.
    /// Note: Actual Watch app installation is verified by startWatchApp(toHandle:) at runtime.
    /// This property only checks HealthKit availability as a prerequisite.
    var canStartWatchApp: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
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
    func startSession(configuration: HKWorkoutConfiguration) async throws

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

### Watch: App Delegate for Receiving Workout Configurations

When iPhone calls `startWatchApp(toHandle:)`, watchOS automatically launches our Watch app and delivers the `HKWorkoutConfiguration` to our app delegate. This is how the system "wakes" the Watch app without explicit WatchConnectivity messaging.

**Setup in the Watch app's main entry point:**

```swift
// Kraftli_Timers_WatchApp.swift
import SwiftUI
import HealthKit

@main
struct Kraftli_Timers_Watch_AppApp: App {
    // Wire up the app delegate to receive workout configurations
    @WKApplicationDelegateAdaptor private var appDelegate: WorkoutAppDelegate

    // ... existing code ...

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.workoutSessionManager)  // Make available to views
        }
    }
}
```

**The app delegate that receives the configuration:**

```swift
// WorkoutAppDelegate.swift
import WatchKit
import HealthKit

final class WorkoutAppDelegate: NSObject, WKApplicationDelegate {
    let workoutSessionManager = WorkoutSessionManager()

    /// Called by watchOS when iPhone sends a workout configuration via startWatchApp(toHandle:)
    /// This is the entry point for Scenario C (iPhone-initiated workouts)
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task {
            do {
                try await workoutSessionManager.startSession(configuration: workoutConfiguration)
            } catch {
                // Handle error — workout can't start
                print("Failed to start workout session: \(error)")
            }
        }
    }

    /// Called when app needs to recover from a crash during an active workout
    func handleActiveWorkoutRecovery() {
        Task {
            do {
                try await workoutSessionManager.recoverActiveSession()
            } catch {
                print("Failed to recover workout session: \(error)")
            }
        }
    }
}
```

**How this works:**

1. iPhone calls `healthStore.startWatchApp(toHandle: configuration)`
2. watchOS wakes/launches our Watch app (even if it wasn't running)
3. watchOS instantiates our `WorkoutAppDelegate` (via `@WKApplicationDelegateAdaptor`)
4. watchOS calls `handle(_ workoutConfiguration:)` with the configuration iPhone sent
5. Our code starts the `HKWorkoutSession` with that configuration

> **Important**: The app delegate class must be marked as the adaptor in the `@main` App struct. Without this, watchOS has no way to deliver the configuration.

### App Store Category Requirement

The `startWatchApp(toHandle:)` API is restricted to apps in the **Healthcare & Fitness** category. Apps in other categories will be rejected during App Store review.

This shouldn't affect Kraftli Timers since it's a fitness app, but it's worth noting.

## 2.5 Xcode Project Configuration

Before writing any code, the following Xcode configuration is required.

### iPhone Target: Kraftli Timers

**Capabilities to add** (Signing & Capabilities → + Capability):

| Capability | Purpose |
|------------|---------|
| HealthKit | Required to write workouts and read heart rate data |

**Info.plist entries** (via Info tab or direct edit):

```xml
<!-- Shown when requesting read access (heart rate for summaries) -->
<key>NSHealthShareUsageDescription</key>
<string>Kraftli Timers reads your heart rate data to display workout summaries.</string>

<!-- Shown when requesting write access (saving workouts) -->
<key>NSHealthUpdateUsageDescription</key>
<string>Kraftli Timers saves your workouts to Apple Health so they appear in the Fitness app and contribute to your Activity Rings.</string>
```

### Watch Target: Kraftli Timers Watch App

**Capabilities to add** (Signing & Capabilities → + Capability):

| Capability | Purpose |
|------------|---------|
| HealthKit | Required to run workout sessions and access sensors |
| Background Modes | Required for workout to continue when screen is off |

**Background Modes settings** (within the Background Modes capability):

| Mode | Enable | Purpose |
|------|--------|---------|
| Workout processing | ✅ Yes | Allows `HKWorkoutSession` to run in background, keeps sensors active |
| Remote notifications | ✅ Already enabled | Existing functionality |
| Session Type | None | Not needed when using `HKWorkoutSession` (it provides its own runtime) |

**Info.plist entries**:

```xml
<!-- Shown when requesting read access -->
<key>NSHealthShareUsageDescription</key>
<string>Kraftli Timers reads your heart rate during workouts.</string>

<!-- Shown when requesting write access -->
<key>NSHealthUpdateUsageDescription</key>
<string>Kraftli Timers saves your workouts to Apple Health with heart rate and calorie data.</string>
```

### What Xcode Generates

When you add these capabilities, Xcode automatically:

1. **Adds entitlements** to `.entitlements` files:
   ```xml
   <key>com.apple.developer.healthkit</key>
   <true/>
   ```

2. **Updates Info.plist** with background modes (Watch):
   ```xml
   <key>WKBackgroundModes</key>
   <array>
       <string>workout-processing</string>
   </array>
   ```

3. **Registers the app** with Apple's provisioning system for HealthKit access

### App Store Category Requirement

The app must be in the **Healthcare & Fitness** category for `startWatchApp(toHandle:)` to work. Apps in other categories will be rejected during App Store review. Kraftli Timers already qualifies as a fitness app.

### Setup Workflow

When ready to implement, follow this order:

1. **iPhone target first**
   - Add HealthKit capability
   - Add privacy descriptions to Info.plist
   - Build and verify no signing errors

2. **Watch target second**
   - Add HealthKit capability
   - Add Background Modes capability
   - Enable "Workout processing" checkbox
   - Add privacy descriptions to Info.plist
   - Build and verify no signing errors

3. **Test on physical devices**
   - Simulator doesn't fully support HealthKit
   - Test permission prompts appear correctly
   - Verify workouts save to Health app

## 2.6 Implementation Phases

### Phase 1A: iPhone-Only Path (Foundation)

1. Create `HealthKitService` on iPhone
2. Add HealthKit capability to project
3. Add permission request flow
4. Save workout to HealthKit when timer completes (no Watch involvement)
5. Store `healthKitWorkoutUUID` in `WorkoutLog`
6. Test: Complete workout on iPhone → appears in Health app

### Phase 1B: Watch Workout Session (Watch-Only)

1. Create `WorkoutSessionManager` on Watch
2. Add HealthKit capability to Watch target
3. Implement `HKWorkoutSession` + `HKLiveWorkoutBuilder` lifecycle
4. Handle Watch-only workouts (Scenario B)
5. Test: Complete workout on Watch → appears in Health app with HR

### Phase 1C: Coordinated Sessions (Both Devices)

1. **Add `WorkoutAppDelegate`** with `WKApplicationDelegate` conformance
2. **Wire up `@WKApplicationDelegateAdaptor`** in Watch app's `@main` struct
3. **Implement `handle(_ workoutConfiguration:)`** to receive configs from iPhone
4. **iPhone: Call `startWatchApp(toHandle:)`** instead of WatchConnectivity for session start
5. **Implement mirrored sessions**: Watch calls `startMirroringToCompanionDevice()`, iPhone sets up `setMirroringStartHandler`
6. Add `WatchMessage.endWorkoutSession` and `workoutSessionEnded` for cleanup
7. Watch sends back `hkWorkoutUUID` when session ends
8. iPhone stores UUID in `WorkoutLog`
9. Test: Start on iPhone with Watch → full metrics in Health

### Phase 1D: Watch-Initiated Workouts (Scenario D)

Building on Phase 1C's mirrored session infrastructure:

1. **Watch: Start mirrored session when timer starts**
   - `WorkoutSessionManager` calls `startMirroringToCompanionDevice()` after starting session
2. **Watch: Send timer context to iPhone**
   - Add `WatchMessage.timerStarted(presetId, scheduledStartTime)`
   - Send when Watch user taps Start
3. **iPhone: Handle incoming timer from Watch**
   - Receive mirrored session in `setMirroringStartHandler`
   - Receive timer message and start `CountdownCoordinator` in mirrored mode
   - Display timer UI (mirrored, not controlling)
4. **iPhone: Graceful degradation**
   - If iPhone app not running: Watch workout proceeds independently
   - If iPhone app launches mid-workout: Can pick up mirrored session state
5. Test: Start on Watch → iPhone shows mirrored timer (if running) → full metrics in Health

### Phase 1E: Edge Cases & Polish

1. Handle permission denied gracefully
2. Handle Watch disconnect mid-workout (workout continues on Watch, saves locally)
3. Handle HealthKit save failures
4. Implement `handleActiveWorkoutRecovery()` for crash recovery
5. Remove `WKExtendedRuntimeSession` (replaced by `HKWorkoutSession`)

## 2.7 Key Technical Considerations

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

### Mirrored Workout Sessions (watchOS 10+)

Mirrored sessions allow iPhone to track the Watch workout session state without custom WatchConnectivity code. When enabled:

- iPhone receives a reference to the Watch's `HKWorkoutSession`
- Session state changes (running, paused, ended) are automatically synchronized
- Both devices can end the workout
- Data can be sent between devices via `sendToRemoteWorkoutSession(data:)`

**Watch side (start mirroring):**
```swift
// After starting the workout session
session.startMirroringToCompanionDevice()
session.startActivity(with: Date())
```

**iPhone side (receive mirrored session):**
```swift
// Set up during app launch
healthStore.setMirroringStartHandler { [weak self] mirroredSession in
    self?.mirroredSession = mirroredSession
    // mirroredSession.state will reflect Watch session state
}
```

**Benefits for Kraftli Timers:**
- iPhone can show workout status without polling
- Either device can end the workout gracefully
- Simplifies state synchronization

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

## 2.8 Open Questions

1. ~~**WKExtendedRuntimeSession replacement**~~: **Resolved.** `HKWorkoutSession` provides extended runtime during active workouts. We can remove `WKExtendedRuntimeSession` when `HKWorkoutSession` is running.

2. **Workout pause behavior**: When user pauses timer, should we pause `HKWorkoutSession`? This affects how the workout appears in Health (paused time included or not). **Recommendation**: Pause the session — it matches user expectation and Health shows pause segments.

3. **Multiple workouts same day**: If user does 3 EMOM sessions, should they be 3 separate workouts or one combined? Current design: 3 separate (simpler, matches user expectation).

4. **Mirrored session data transfer**: Should we use `sendToRemoteWorkoutSession(data:)` for timer state, or keep using WatchConnectivity? **Consideration**: Mirrored session data is more reliable for workout-critical data, but WatchConnectivity may be better for our existing timer sync code. Evaluate during Phase 1C.

## 2.9 Integration with Existing Components

This section addresses how HealthKit integration interacts with existing Watch-iPhone communication infrastructure.

### Existing Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iPhone                                   │
│  ┌──────────────────┐         ┌─────────────────────────────┐   │
│  │ TimerSyncService │────────▶│ WatchConnectivityService    │   │
│  │ (protocol)       │         │ (WCSession wrapper)         │   │
│  └──────────────────┘         └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Apple Watch                               │
│  ┌─────────────────────────────┐    ┌────────────────────────┐  │
│  │ WatchConnectivityService    │───▶│ WatchMessageCoordinator│  │
│  └─────────────────────────────┘    └────────────────────────┘  │
│                                              │                   │
│                                              ▼                   │
│                                     ┌────────────────────────┐  │
│                                     │ WatchTimerSyncService  │  │
│                                     │ (protocol)             │  │
│                                     └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Service Responsibilities After HealthKit Integration

**`TimerSyncService` (iPhone)** — Extend, don't replace:
- Existing: `startTimerOnWatch()`, `sendTimerControl()`, `timerControlReceived`
- Add: Methods for workout session messages (`endWorkoutSession`, handling `workoutSessionEnded`)
- Rationale: Keep timer sync abstracted behind protocol for testability

**`WatchTimerSyncService` (Watch)** — Extend, don't replace:
- Existing: `sendTimerControl()`, `timerControlReceived`
- Add: Methods for `timerStarted` (Scenario D), `workoutSessionEnded`
- Rationale: Same abstraction benefits as iPhone side

**`WatchMessageCoordinator` (Watch)** — Separate concerns:
- Continues routing timer messages to `WatchTimerSyncService`
- Does NOT handle `HKWorkoutConfiguration` — that's `WorkoutAppDelegate`'s job
- May gain reference to `WorkoutSessionManager` to forward `endWorkoutSession` messages

**`WorkoutAppDelegate` (Watch, new)** — Workout-specific entry point:
- Receives `HKWorkoutConfiguration` from system via `handle(_:)`
- Owns `WorkoutSessionManager` instance
- Separate from `WatchMessageCoordinator` — different trigger mechanisms

### The `displayOnly` Flag

**Current behavior** (`StartTimerMessage.displayOnly`):
- `true`: Watch displays timer but doesn't log workout (iPhone is source of truth)
- `false`: Watch logs workout to SwiftData

**With HealthKit integration**, this flag becomes **obsolete for Scenarios C and D**:

| Scenario | Watch runs HKWorkoutSession? | Who logs to HealthKit? | `displayOnly` meaning |
|----------|------------------------------|------------------------|-----------------------|
| A (iPhone only) | No | iPhone (duration only) | N/A — Watch not involved |
| B (Watch only) | Yes | Watch | N/A — iPhone not involved |
| C (iPhone leads) | Yes | Watch | **Obsolete** — Watch must run session for sensors |
| D (Watch leads) | Yes | Watch | **Obsolete** — Watch initiated |

**Migration plan**:
1. Phase 1A/1B: `displayOnly` continues working for non-HealthKit path
2. Phase 1C: When iPhone starts workout with Watch, it uses `startWatchApp(toHandle:)` instead of `startTimerOnWatch()` — `displayOnly` not sent
3. Phase 1E: Deprecate `displayOnly` flag; all Watch-involved workouts use HealthKit path

**Alternative**: Repurpose `displayOnly` to mean "don't show workout UI on Watch, just collect sensor data." Evaluate during Phase 1C if this use case exists.

### Message Flow Clarification

**Scenario C (iPhone leads)** — Two communication channels:

1. **HealthKit channel** (workout session):
   - iPhone: `startWatchApp(toHandle: config)` → System launches Watch app
   - Watch: `WorkoutAppDelegate.handle(_:)` receives config
   - Watch: Starts `HKWorkoutSession`, calls `startMirroringToCompanionDevice()`
   - iPhone: Receives mirrored session via `setMirroringStartHandler`

2. **WatchConnectivity channel** (timer sync):
   - iPhone: Sends `startTimer` message with preset details via `TimerSyncService`
   - Watch: `WatchMessageCoordinator` routes to timer view
   - Bidirectional: `pauseTimer`, `resumeTimer`, `stopTimer` via existing flow
   - Watch → iPhone: `workoutSessionEnded(hkWorkoutUUID)` when session completes

**Why two channels?** The HealthKit APIs (`startWatchApp`, mirrored sessions) handle workout session lifecycle. WatchConnectivity handles our app-specific timer state (which preset, current interval, pause/resume). Keeping them separate means:
- Workout session can start even if WatchConnectivity message is delayed
- Timer sync continues working if mirrored session has issues
- Existing timer sync code requires minimal changes

### Preset Sync (CloudKit Only)

Presets sync between iPhone and Watch via CloudKit/SwiftData automatic sync. WatchConnectivity is not used for preset data — it handles only real-time timer control messages (start/pause/stop). Both devices are equal peers; presets created on either device sync bidirectionally through iCloud. A deduplication pass on launch removes any duplicates caused by CloudKit merge conflicts.

---

## References

### Apple Documentation
- [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
- [HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [HKLiveWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder)
- [startWatchApp(with:completion:)](https://developer.apple.com/documentation/healthkit/hkhealthstore/1648358-startwatchappwithworkoutconfigur) — The key API for launching Watch workouts from iPhone
- [WKApplicationDelegate](https://developer.apple.com/documentation/watchkit/wkapplicationdelegate) — Watch app delegate that receives workout configurations
- [Building a multidevice workout app](https://developer.apple.com/documentation/HealthKit/building-a-multidevice-workout-app)

### WWDC Sessions
- [Build a multi-device workout app (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10023/) — Covers mirrored sessions
- [Build custom workouts with WorkoutKit (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10016/) — WorkoutKit for Workout app integration
- [Building Great Workout Apps (WWDC16)](https://asciiwwdc.com/2016/sessions/235) — Original `startWatchApp` introduction

### Community Resources
- [Building a Workout App for Apple Watch (Sasquatch Studio)](https://sasq.ca/blog/2025/3/2/building-a-workout-app-for-apple-watch) — Modern implementation guide
- [From YaoYao to Tooboo: watchOS Development Pitfalls](https://fatbobman.com/en/posts/watchos-development-pitfalls-and-practical-tips/) — Practical tips including Healthcare & Fitness category requirement

### Note on WorkoutKit
WorkoutKit is for composing structured workouts that sync to Apple's Workout app. It's **not** what we use for real-time session control. For custom workout apps like Kraftli Timers, use HealthKit's `HKWorkoutSession` directly.
