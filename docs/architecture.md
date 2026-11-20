# Architecture

Data models, patterns, and key components: *how* the system is built. *What* it must do is
specified in the [use cases](use-cases/); *why* it is built this way is recorded in the
[ADRs](adr/).

## Domain Model Summary

Quick reference for the core domain types:

| Type | Purpose |
|------|---------|
| `TimerPreset` | Saved timer configuration: id, kind, duration (0 for For Time), exerciseId, reps (EMOM, For Time), sortOrder |
| `TimerKind` | Enum: EMOM \| AMRAP \| For Time |
| `ExerciseInfo` | Bundled, in-memory exercise reference data: id, name, description, formTips, muscleGroup, difficulty, isHold, secondsPerRep ([ADR-0009](adr/ADR-0009-bundled-exercise-library.md)) |
| `Exercise` | Legacy SwiftData model, unused; kept in the schema because CloudKit schema changes are additive only |
| `TrainingSession` | Named training session: id, name, and its elements as one versioned JSON document ([ADR-0011](adr/ADR-0011-session-document-and-week-plan-record.md)) |
| `SessionElement` | A session's building block, a plain Codable value: a `SessionStep` (one timer, stored like a preset) or a `SessionLoop` (steps, 2–20 rounds, rest). Not a SwiftData model, but kept in `Models/` next to `TrainingSession`, whose stored format it is |
| `WeekPlan` | The training week: one optional session id per weekday; an id without a session counts as a rest day |
| `WorkoutLog` | Recorded workout: id, date, exerciseName, timerKind, durationSeconds, repsCompleted, roundsCompleted, healthKitWorkoutUUID, stoppedEarly, sessionName, sessionRunID |
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
    var durationInterval: TimeInterval  // 0 for For Time (no duration)
    var targetReps: Int?          // EMOM and For Time; nil for AMRAP
    var sortOrder: Int            // For list ordering
    var exerciseId: UUID?         // Reference into the bundled library
    var exercise: Exercise?       // Legacy relationship (unused)

    // Computed
    var kind: TimerKind
    var duration: Duration
    var primaryText: String       // "EMOM · 20 min", "For Time"
    var secondaryText: String     // "Exercise · 10 Reps"
    var exerciseInfo: ExerciseInfo?   // Looked up by exerciseId
    var intervalDuration: TimeInterval  // duration / reps (or 60 default)

    // Static utilities
    static let minimumIntervalDuration: TimeInterval = 3
    static let forTimeRepsRange = 1...999
    static let defaultForTimeReps = 100
    static func maximumReps(forDuration: TimeInterval) -> Int
}
```

### TimerKind
```swift
enum TimerKind: String, CaseIterable {
    case emom = "EMOM"
    case amrap = "AMRAP"
    case forTime = "For Time"

    var hasFixedDuration: Bool    // false for For Time
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
    let isHold: Bool            // held for time, not counted in reps; never For Time
    let secondsPerRep: Double?  // typical pace, for estimating For Time; nil for holds
}
// ExerciseRepository decodes Exercises.json into ExerciseInfo at startup; the legacy `Exercise`
// @Model stays in the schema, unused (ADR-0009).
```

### WorkoutLog (SwiftData @Model)
```swift
@Model
final class WorkoutLog {
    var id: UUID
    var date: Date
    var exerciseName: String           // Snapshot (not reference)
    var timerKindRawValue: String
    var durationSeconds: TimeInterval  // For Time: the finish time, to the second
    var repsCompleted: Int?            // EMOM and For Time
    var roundsCompleted: Int?          // AMRAP only
    var healthKitWorkoutUUID: UUID?    // Correlation with Apple Health entry
    var stoppedEarly: Bool             // Ended early: duration = active time, counts so far
    var sessionName: String?           // Step of a session: its name then (text, not a reference)
    var sessionRunID: UUID?            // The run its steps share; links them to its one Health workout

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

User preferences are managed via `AppSettings`, an `@Observable` class whose stored properties persist to `UserDefaults` in `didSet`.

See [ADR-0001: Settings Pattern](adr/ADR-0001-settings-pattern.md) for full decision rationale and implementation details.

## Timer Sync & HealthKit Architecture

A workout that runs on both devices has **exactly one owner** of its timer state (ADR-006). The
owner publishes the whole state as a versioned snapshot; the other device is a **viewer** that
renders the newest snapshot and sends its taps as **intents** (ADR-007).

**The state** — `TimerState` (`Services/TimerState.swift`, shared):
- `startDate`, `pausedAt`, `accumulatedPause`, `roundCount`, `finish`, plus `revision`, `owner`
  and the immutable `TimerConfig`
- `TimerConfig.totalDuration` is optional: nil marks an open-ended For Time workout, which never
  completes by itself and ends with a `done` intent recorded as `.completed` (ADR-0010)
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

A workout ended early is judged by `EarlyStop`, a pure rule over the `TimerState` that both
devices apply alike (UC-0005 extensions 1a–1b): under one minute of active time nothing is
recorded and the Watch discards its Health workout; from one minute on, the starting device
writes the log marked `stoppedEarly`, and the owner saves the Health workout as usual.

**Sessions** (ADR-0012): every step of a training session is such a workout of its own, started
one after the other by `SessionRunner` on the iPhone. The owner of the first step holds the
session's Health workout to the end. A step's `StartRequest` names the run (`SessionContext`);
a Watch that already holds the run owns the step at once and keeps its `HKWorkoutSession`. The
iPhone sends a numbered `SessionStatus` on every change of phase, from which
`WatchSessionFollower` pauses the Health session between steps, keeps it running through steps
and loop rests, and saves it when the session is finished. The Watch reports the saved workout
under the run's ID, and the iPhone links it to every step's `WorkoutLog` and shows its heart
rate and calories in the session summary. The status also carries what is up next and the
session's shape, which `WatchSessionView` shows between steps, layered over the Watch's timer
list while the follower holds a run.

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
| `TimerSettingsForm` | The form for one timer's settings (kind, exercise, wheels), shared by the preset editor and the step editor |
| `TrainingView` | Training tab: week strip, the selected day's session, session list |
| `SessionRunnerView` | Full-screen runner of a session: one screen per phase of the run (up next, running step on the kind's timer screen, loop rest, summary) |
| `SessionEditorView` | Block editor for a session; works on a `SessionDraft`, reorders by drag and drop, also into and out of loops |
| `StepEditorView` | Editor for one timer of a session, on a `PresetDraft` |
| `SessionShapeBar`, `SessionShapeColumn` | A session drawn as a bar of segments, coloured by kind and sized by duration: lying (cards, editor) and upright (week strip) |
| `ExerciseSelectionView` | Exercise browser with filtering |
| `TimerScreen` | The screen all three timer kinds run on: starts the workout, follows the timer session, countdown, gestures. Derives the phase, tap hint, VoiceOver text, tap/hold behaviour and layout from the kind. A container view; the kinds fill its ring and center slots (usually a `TimerCenterStack`) |
| `KindTimerView` | The one place that maps a `TimerConfig`'s kind to its timer view and model; used by `TimerRunnerView` and `SessionRunnerView`. The Watch's counterpart is `WatchKindTimerView` |
| `TimerChrome` | What a timer screen shares with the view presenting it: tap hint, confetti, swipe disabled during the countdown, and `endWorkout` for the swipe-down (@Observable) |
| `EMOMTimerView` | EMOM face of `TimerScreen`: two rings, interval time |
| `AMRAPTimerView` | AMRAP face of `TimerScreen`: one ring, round count |
| `ForTimeTimerView` | For Time face of `TimerScreen`: circling arc, tap = done |
| `CountdownCoordinator` | 3-2-1-GO display toward the shared start date (shared with the Watch; the iPhone signals each count through the `FeedbackProvider`) |
| `StatsView` | Workout statistics dashboard |
| `WorkoutListView` | Workout list with edit/delete: all workouts, or one exercise's within the chosen period. Runs its own query |
| `WorkoutLogEditorView` | Edit reps/rounds for a workout |
| `SettingsView` | User preferences and app info |

### Timer Models
| Model | Purpose |
|-------|---------|
| `TimerModel` | Protocol + extension shared by the three timer models: adopts a `TimerState`, ticks while it runs, detects completion (`isCompleted`), and gives the workout's `WorkoutResult`. Its stored state — elapsed time, round count, running/completed flags and the tick timer — lives in `TimerRenderCore` (shared with the Watch) |
| `EMOMTimerModel` | Renders an EMOM `TimerState`: interval display and feedback (@Observable) |
| `AMRAPTimerModel` | Renders an AMRAP `TimerState`: remaining time and rounds (@Observable) |
| `ForTimeTimerModel` | Renders an open-ended `TimerState`: elapsed time, finish time and pace (@Observable, shared with the Watch) |

The models store no display state: every displayed value is a computed property over the
core's `elapsed`, so adopting a state or a tick only sets the elapsed time. EMOM's interval
beeps are its only per-kind hook (`didAdopt` seeds them, `didTick` plays them).

### Training Logic
Plain values and pure functions in `Features/Training/`, next to the views that use them.

| Type | Purpose |
|------|---------|
| `SessionDraft` | The session editor's values and rules: validation, adding, reordering, moving timers between the session and its loops, saving |
| `SessionOrder` | The one rule for a session's running order: loops unrolled, a rest after each round but the last |
| `SessionRun` | One run through a session as a value: position, phase, every timer's result, active stretches and total time; all rules of running, tested with plain dates |
| `SessionRunner` | Drives a `SessionRun` on the iPhone: a new workout ID per step, records each step, times the rests, reports every change of phase to the Watch as a `SessionStatus`, and saves the session's Health workout unless the Watch holds it (@Observable) |
| `SessionEstimate` | A session's segments in running order, its estimated length and summary text; For Time = pace × reps^1.1 |
| `ShapeLayout` | The measurements of a session's shape: segment lengths, gaps, loop runs |
| `SessionNaming`, `WeekLayout`, `WeekPlanning` | Unique and copy names; weekday order by region; planning a day and deleting a session with its days |

### Services
| Service | Purpose |
|---------|---------|
| `TimerProvider` | Protocol for the tick timer that drives a timer model's re-rendering |
| `DisplayLinkTimerProvider` | CADisplayLink ticks (Smooth Animations on) |
| `FoundationTimerProvider` | 0.2 s Foundation Timer (Smooth Animations off; always on Watch) |
| `FeedbackProvider` | Protocol for countdown/interval/completion feedback (`SilentFeedback` when Sound is off and on the Watch) |
| `DefaultFeedback` | Interval beep + completion cue (cheering or three beeps) |
| `StatsService` | Compute workout statistics |
| `WorkoutLoggingService` | Log completed workouts to SwiftData |
| `WorkoutRecorder` | iPhone: records a completed or early-stopped workout — the log always, the Health workout when the iPhone owned the timer (ADR-0006 §1). A session's step gets the log only; `recordSession` then saves one Health workout for the run, with the waits as pauses, and links every step's log to it. Injected through the environment; silent by default |
| `ExerciseRepository` / `ExerciseLoader` | Load the bundled exercise library into memory |
| `PresetMaintenance` | Startup migration + CloudKit duplicate cleanup (deletes on iPhone only) |
| `HealthKitService` | iPhone: authorization, workout saving, Watch app launching |
| `TimerState` / `TimerStateReducer` | Shared: replicated timer state and the only code that changes it |
| `EarlyStop` | Shared: whether a workout ended early is recorded or discarded, and with what |
| `WorkoutResult` | Shared: what a workout achieved (duration, reps, rounds); history entries and completion reports are built from it |
| `SessionContext` / `SessionStatus` | Shared: the run a step's start request belongs to, and the session's progress the iPhone sends the Watch one way (ADR-0012) |
| `WatchSessionFollower` | Watch: holds one Health session for a session's run across its steps; pauses, resumes, saves or discards it from the `SessionStatus`; keeps the latest status and a just-finished run for `WatchSessionView`; can end the session from the Watch by saving its workout, whose report ends the session on the iPhone (@Observable) |
| `TimerSessionController` | Shared: one device's role (owner/viewer), confirmed state, pending intents (@Observable) |
| `TimerSyncTransport` | Shared: payloads, inbox filtering, composite + WatchConnectivity channels |
| `HealthKitTimerSyncTransport` | Shared: payloads over the mirrored `HKWorkoutSession` data channel |
| `PhoneWorkoutStarter` | iPhone: start handshake with the Watch, fallback to iPhone ownership (@Observable) |
| `PhoneMessageCoordinator` | iPhone: links the Watch's Health UUID to the `WorkoutLog`, publishes its summary |
| `PhoneTimerRuntime` | iPhone: app-lifetime owner of timer session, starter, message coordinator and recorder; built in `App.init` |
| `MirroredWorkoutObserver` | iPhone: holds the Watch's mirrored session for the HealthKit channel |
| `AppSettings` | User preferences (@Observable + UserDefaults) |

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
| `WatchWorkoutScreen` | The screen all three timer kinds run on, on the Watch: starts or joins the workout, countdown, controls page, heart rate and calories. The kinds supply their metric rows |
| `WatchEMOMTimerView` | EMOM face of `WatchWorkoutScreen` |
| `WatchAMRAPTimerView` | AMRAP face of `WatchWorkoutScreen` (tap = round) |
| `WatchForTimeTimerView` | For Time face of `WatchWorkoutScreen` (tap = done) |

### watchOS Services
| Service | Purpose |
|---------|---------|
| `WatchTimerRuntime` | Watch: app-lifetime owner of session manager, timer session and starter (shared instance) |
| `WatchWorkoutStarter` | Watch: answers start requests, takes ownership or yields, Watch-started workouts (asks for Health access first while undecided; discards a session that starts after its workout ended) (@Observable) |
| `WatchTimerSyncService` | Watch: sends `WorkoutSessionEndedMessage` to iPhone (protocol → default → silent) |
| `WatchWorkoutCoordinator` | Watch: end-of-workout logic of `WatchWorkoutScreen` (end session, log or report) |
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
- `TimerKind+UI` - Timer kind display colors and glyphs (`timer.interval`, `timer.amrap`, `timer.simple`)
