# Architecture

Data models, patterns, and key components: *how* the system is built. *What* it must do is
specified in the [use cases](use-cases/); *why* it is built this way is recorded in the
[ADRs](adr/).

## Domain Model Summary

Quick reference for the core domain types:

| Type | Purpose |
|------|---------|
| `TimerPreset` | Saved timer configuration: id, kind, duration, exerciseId, reps (EMOM), sortOrder |
| `TimerKind` | Enum: EMOM \| AMRAP |
| `ExerciseInfo` | Bundled, in-memory exercise reference data: id, name, description, formTips, muscleGroup, difficulty ([ADR-0009](adr/ADR-0009-bundled-exercise-library.md)) |
| `Exercise` | Legacy SwiftData model, kept in the schema for migration only |
| `WorkoutLog` | Completed workout: id, date, exerciseName, timerKind, durationSeconds, repsCompleted, roundsCompleted, healthKitWorkoutUUID |
| `MuscleGroup` | Enum: fullBody \| upperBody \| lowerBody \| core |
| `Difficulty` | Enum: beginner \| intermediate \| advanced |

## Patterns

- **SwiftData + CloudKit** for persistence, both devices as peers (@Model classes, @Query for fetching; [ADR-0008](adr/ADR-0008-swiftdata-cloudkit-persistence.md))
- **Observable** macro for runtime state management (timer models)
- **Dependency Injection** for testability (timer providers, audio feedback)
- **Protocol-based abstractions** for services: `protocol` → `Default…` (production) → `Silent…`
  (previews/tests, fails quietly). Time and scheduling are injectable (`now`, `schedules…` flags) so
  timing logic is unit-testable
- **Shared code** between the iOS and watchOS targets lives in the iOS folders and is added to the
  Watch target via Xcode membership exceptions; platform differences use `#if os()`
- **Single-owner timer state** replicated as snapshots over every transport ([ADR-0006](adr/ADR-0006-single-owner-timer-state.md), [ADR-0007](adr/ADR-0007-optimistic-viewer-control.md))

## Data Models

### TimerPreset (SwiftData @Model)
```swift
@Model
final class TimerPreset {
    var id: UUID
    var kindRawValue: String      // Stored as string for SwiftData
    var durationInterval: TimeInterval
    var targetReps: Int?          // Optional, only for EMOM
    var sortOrder: Int            // For list ordering
    var exerciseId: UUID?         // Reference into the bundled library
    var exercise: Exercise?       // Legacy relationship (migration only)

    // Computed
    var kind: TimerKind
    var duration: Duration
    var primaryText: String       // "EMOM · 20 min"
    var secondaryText: String     // "Exercise · 10 Reps"
    var exerciseInfo: ExerciseInfo?   // Looked up by exerciseId
    var intervalDuration: TimeInterval  // duration / reps (or 60 default)

    // Static utilities
    static let minimumIntervalDuration: TimeInterval = 3
    static func maximumReps(forDuration: TimeInterval) -> Int
}
```

### TimerKind
```swift
enum TimerKind: String, CaseIterable {
    case emom = "EMOM"
    case amrap = "AMRAP"
}
```

### ExerciseInfo (in-memory reference data)
```swift
struct ExerciseInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let formTips: [String]
    let muscleGroup: MuscleGroup
    let difficulty: Difficulty?
}
// ExerciseRepository loads Exercises.json at startup; the legacy `Exercise` @Model stays in the
// schema only so the exerciseId migration can read old relationships (ADR-0009).
```

### WorkoutLog (SwiftData @Model)
```swift
@Model
final class WorkoutLog {
    var id: UUID
    var date: Date
    var exerciseName: String           // Snapshot (not reference)
    var timerKindRawValue: String
    var durationSeconds: TimeInterval
    var repsCompleted: Int?            // EMOM only
    var roundsCompleted: Int?          // AMRAP only
    var healthKitWorkoutUUID: UUID?    // Correlation with Apple Health entry

    // Computed
    var timerKind: TimerKind
    var durationMinutes: Int
    var formattedDate: String
    var summaryText: String
}
```

### Enums

```swift
enum MuscleGroup: String, Codable, CaseIterable {
    case fullBody, upperBody, lowerBody, core
    var displayName: String
    var color: Color  // UI extension
}

enum Difficulty: String, Codable, CaseIterable {
    case beginner, intermediate, advanced
    var displayName: String
    var color: Color  // UI extension
}

enum TimePeriod: String, CaseIterable {
    case week, month, sixMonths, year
    var displayName: String
    var dateRange: (start: Date, end: Date) -> (Date, Date)
    var bucketUnit: BucketUnit
}
```

## State Management

- `@Model` for persisted data (SwiftData)
- `@Query` for reactive data fetching
- `@Observable` for runtime timer state
- `@State` for view-local state
- `@Environment(\.modelContext)` for CRUD operations
- `@Environment(AppSettings.self)` for user preferences
- `@Environment(WorkoutSessionManager.self)` for shared workout session (Watch)
- `@Environment(TimerSessionController.self)` for the app's one timer session (both devices)
- `@Environment(PhoneWorkoutStarter.self)` / `@Environment(WatchWorkoutStarter.self)` for starting workouts
- `@WKApplicationDelegateAdaptor` for receiving workout configs from iPhone (Watch)
- `@MainActor` isolation for thread safety

## Settings Architecture

User preferences are managed via `AppSettings`, an `@Observable` class with `@AppStorage` properties.

See [ADR-0001: Settings Pattern](adr/ADR-0001-settings-pattern.md) for full decision rationale and implementation details.

## Timer Sync & HealthKit Architecture

A workout that runs on both devices has **exactly one owner** of its timer state (ADR-006). The
owner publishes the whole state as a versioned snapshot; the other device is a **viewer** that
renders the newest snapshot and sends its taps as **intents** (ADR-007).

**The state** — `TimerState` (`Services/TimerState.swift`, shared):
- `startDate`, `pausedAt`, `accumulatedPause`, `roundCount`, `finish`, plus `revision`, `owner`
  and the immutable `TimerConfig`
- Everything on screen is derived from the state and the local clock (`elapsed(at:)`), so both
  devices compute the same remaining time from the same absolute dates
- The 3-2-1 countdown is implicit: `now < startDate`
- Only `TimerStateReducer` changes it — a pure function the owner uses to apply intents and the
  viewer uses to predict its own pending intents

**Ownership:**

| Situation | Owner |
|-----------|-------|
| Started on iPhone, Watch confirms within 5 s | Watch |
| Started on iPhone, no Watch / Watch app not installed | iPhone (no wait) |
| Started on iPhone, Watch launch fails or times out | iPhone (a late Watch yields) |
| Started on Watch | Watch |

The Watch is preferred because it runs the primary `HKWorkoutSession` (heart rate, calories,
background runtime). **Whoever owns the timer also saves the Health workout**, so each workout is
saved exactly once. The device that *started* the workout writes the SwiftData `WorkoutLog`.

**Start handshake** (iPhone-started, `PhoneWorkoutStarter` ↔ `WatchWorkoutStarter`):
1. iPhone sends a `StartRequest` (workout ID + config) and calls
   `HKHealthStore.startWatchApp(toHandle:)`; the UI shows "Starting on Watch…"
2. Watch starts its `HKWorkoutSession`, takes ownership (revision 1, `startDate = now + 3 s`) and
   starts mirroring; both devices count down to the same instant
3. No answer within 5 s (or a failed launch) → the iPhone owns the workout; its snapshot replaces
   the request, and a Watch that starts late yields (discards its session, follows as a viewer)

**Transports** — `CompositeTimerSyncTransport` publishes on every channel; `TimerSyncInbox` keeps
only the highest revision of the expected workout and drops seen intents, so duplicates, reordering
and redelivery are harmless:
- HealthKit mirrored-session data (`sendToRemoteWorkoutSession`) while a workout is mirrored
- WatchConnectivity: snapshots as application context + `sendMessage`; intents via `sendMessage` +
  `transferUserInfo`; the final snapshot also via `transferUserInfo`
- On reconnect the owner republishes its latest snapshot; the viewer resends pending intents

**HealthKit's pause/resume** is a consequence of the state (the owner pauses its session when
`pausedAt` changes), not a control channel. Mirrored-session state never drives the timer.

**After the workout** the Watch sends `WorkoutSessionEndedMessage` (Health UUID, heart rate,
calories; `sendMessage` + `transferUserInfo`). `PhoneMessageCoordinator` links the UUID to the
`WorkoutLog` whose ID is the workout ID and publishes it for the summary screen.

See [ADR-0002: HealthKit Integration](adr/ADR-0002-healthkit-integration.md),
[ADR-0006: Single-owner timer state](adr/ADR-0006-single-owner-timer-state.md) and
[ADR-0007: Optimistic viewer control](adr/ADR-0007-optimistic-viewer-control.md).

## Key Components

### Views
| View | Purpose |
|------|---------|
| `ContentView` | Tab-based navigation container |
| `TimerPresetView` | Preset list with CRUD operations |
| `TimerPresetEditorView` | Create/edit preset sheet |
| `ExerciseSelectionView` | Exercise browser with filtering |
| `EMOMTimerView` | Full-screen EMOM timer |
| `AMRAPTimerView` | Full-screen AMRAP timer |
| `StatsView` | Workout statistics dashboard |
| `WorkoutListView` | Filtered workout list (by exercise) |
| `AllWorkoutsView` | Global workout list with edit/delete |
| `WorkoutLogEditorView` | Edit reps/rounds for a workout |
| `SettingsView` | User preferences and app info |

### Timer Models
| Model | Purpose |
|-------|---------|
| `EMOMTimerModel` | Renders an EMOM `TimerState`: interval display and feedback (@Observable) |
| `AMRAPTimerModel` | Renders an AMRAP `TimerState`: remaining time and rounds (@Observable) |
| `TimerSessionState` | Shared hint/confetti state management (@Observable) |

### Services
| Service | Purpose |
|---------|---------|
| `TimerCoordinator` | Tick scheduler: drives a timer model from a `TimerProvider` |
| `TimerProvider` | Protocol for timer implementations |
| `DisplayLinkTimerProvider` | CADisplayLink ticks (Smooth Animations on) |
| `FoundationTimerProvider` | 0.2 s Foundation Timer (Smooth Animations off; always on Watch) |
| `FeedbackProvider` | Protocol for interval/completion feedback (`SilentFeedback` when Sound is off and on the Watch) |
| `SystemSoundFeedback` | Interval beep + cheering completion sound |
| `NeutralSoundFeedback` | Interval beep + three-beep completion |
| `StatsService` | Compute workout statistics |
| `WorkoutLoggingService` | Log completed workouts to SwiftData |
| `ExerciseRepository` / `ExerciseLoader` | Load the bundled exercise library into memory |
| `PresetMaintenance` | Startup migration + CloudKit duplicate cleanup (deletes on iPhone only) |
| `HealthKitService` | iPhone: authorization, workout saving, Watch app launching |
| `TimerState` / `TimerStateReducer` | Shared: replicated timer state and the only code that changes it |
| `TimerSessionController` | Shared: one device's role (owner/viewer), confirmed state, pending intents (@Observable) |
| `TimerSyncTransport` | Shared: payloads, inbox filtering, composite + WatchConnectivity channels |
| `HealthKitTimerSyncTransport` | Shared: payloads over the mirrored `HKWorkoutSession` data channel |
| `PhoneWorkoutStarter` | iPhone: start handshake with the Watch, fallback to iPhone ownership (@Observable) |
| `PhoneMessageCoordinator` | iPhone: links the Watch's Health UUID to the `WorkoutLog`, publishes its summary |
| `MirroredWorkoutObserver` | iPhone: holds the Watch's mirrored session for the HealthKit channel |
| `AppSettings` | User preferences (@Observable + @AppStorage) |

### UI Components
| Component | Purpose |
|-----------|---------|
| `ProgressRing` | Circular progress indicator |
| `RepsPill` | Styled capsule badge |
| `Pill` | Generic colored pill |
| `MuscleGroupTag` | Type-safe muscle group pill |
| `DifficultyIndicator` | Difficulty dot or pill |
| `ExerciseCardView` | Expandable exercise card |
| `ConfettiView` | Celebratory particle animation (CAEmitterLayer) |
| `SummaryCard` | Stats summary card |
| `ExerciseStatsCard` | Per-exercise stats display |
| `ActivityChart` | Bar chart for workout minutes |
| `WorkoutRow` | Card-style workout list row |

### Shared Modifiers
| Modifier | Purpose |
|----------|---------|
| `CardListRowModifier` | Card-style list row: no separator, clear background, standard insets |
| `CardListStyleModifier` | Card-style list container: plain style, hidden scroll background |
| `DragHandleView` | Swipe-to-dismiss handle |
| `SwipeHintOverlay` | "Swipe down to close" hint |
| `SwipeToDismissModifier` | Swipe gesture handling |
| `TimerLifecycleModifier` | Background pause (iPhone-owned workouts only), idle timer, completion |

### watchOS Components
| Component | Purpose |
|-----------|---------|
| `WatchPresetListView` | Preset list with swipe actions for edit/delete |
| `WatchPresetEditorView` | Create/edit preset with Digital Crown input |
| `WatchExerciseListView` | Simple exercise picker with checkmark selection |
| `DigitalCrownStepperView` | Reusable Digital Crown numeric input |
| `WatchEMOMTimerView` | Full-screen EMOM timer for Watch |
| `WatchAMRAPTimerView` | Full-screen AMRAP timer for Watch |

### watchOS Services
| Service | Purpose |
|---------|---------|
| `WatchTimerRuntime` | Watch: app-lifetime owner of session manager, timer session and starter (shared instance) |
| `WatchWorkoutStarter` | Watch: answers start requests, takes ownership or yields, Watch-started workouts (@Observable) |
| `WatchTimerSyncService` | Watch: sends `WorkoutSessionEndedMessage` to iPhone (protocol → default → silent) |
| `WatchWorkoutCoordinator` | Watch: end-of-workout logic shared by EMOM and AMRAP (end session, log or report) |
| `WorkoutSessionManager` | HKWorkoutSession/HKLiveWorkoutBuilder lifecycle (@Observable) |
| `WorkoutAppDelegate` | WKApplicationDelegate: receives workout configs from iPhone |

## Utilities

- `TimeInterval+Format` - MM:SS, HH:MM:SS, and interval description formatting
- `View+PaddedDomain` - `ifLet` conditional view modifier helper
- `Logger+App` - Categorized `os.Logger` instances
- `UISeparator` - Consistent separator characters (e.g., middle dot)
- `TimePeriod+Chart` - Chart x-axis unit for time periods
- `Difficulty+UI` - Difficulty display colors
- `MuscleGroup+UI` - Muscle group display colors
- `TimerKind+UI` - Timer kind display colors
