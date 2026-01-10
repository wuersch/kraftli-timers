# Workout Stats - Architecture Plan

**Status**: Approved for implementation
**Created**: 2026-01-10
**Feature Spec**: See [SPEC.md](./SPEC.md) → Workout Stats section

---

## Overview

This document describes the implementation architecture for the Workout Stats feature. The design follows a service-oriented approach with clean separation between persistence, business logic, and presentation.

### Design Principles
- **Service layer for logic**: Keep views focused on presentation
- **Protocol-based abstractions**: Enable testing and future extensibility (HealthKit)
- **SwiftData + @Query**: Leverage existing persistence patterns
- **Minimal new components**: Reuse existing design system (Pill, cards)

---

## Architecture Decisions

### 1. Workout Logging: Service Protocol
**Decision**: Introduce `WorkoutLoggingService` protocol
**Rationale**:
- Separates logging concern from timer logic
- Future HealthKit integration requires this abstraction
- Testable (mock service for tests)
- Follows existing pattern (`AudioFeedbackProvider`)

### 2. Stats Computation: Service Protocol
**Decision**: Introduce `StatsService` protocol
**Rationale**:
- Complex aggregations stay out of views
- Views remain thin (layout + presentation only)
- Reusable across different stats views
- Easier to test aggregation logic

### 3. Exercise Lookup: Denormalized Name + Live Lookup
**Decision**: Store exercise name in WorkoutLog, lookup muscle group at display time
**Rationale**:
- Historical accuracy (preset edits don't affect past logs)
- Muscle group corrections reflect in stats
- No cascade delete concerns

### 4. Timer Integration: Lifecycle Modifier Extension
**Decision**: Extend `TimerLifecycleModifier` with logging callback
**Rationale**:
- Completion detection already exists (line 42-46)
- Centralized integration point
- Timer models stay pure (no persistence concerns)

### 5. Chart Implementation: Direct Swift Charts
**Decision**: Use Swift Charts directly without generic wrapper
**Rationale**:
- Single chart type needed (bar chart)
- Avoids over-abstraction
- Can extract wrapper later if more chart types added

---

## Data Model

### WorkoutLog (SwiftData @Model)

```swift
@Model
final class WorkoutLog {
    // Persisted
    var id: UUID
    var date: Date
    var exerciseName: String           // Snapshot, not reference
    var timerKindRawValue: String      // "EMOM" or "AMRAP"
    var durationSeconds: TimeInterval
    var repsCompleted: Int?            // EMOM only
    var roundsCompleted: Int?          // AMRAP only

    // Computed
    var timerKind: TimerKind { get }
    var durationMinutes: Int { get }
}
```

### TimePeriod (Enum)

```swift
enum TimePeriod: String, CaseIterable {
    case week, month, year

    var displayName: String { get }
    func dateRange(from referenceDate: Date) -> (start: Date, end: Date)
}
```

### ExerciseStats (Value Type)

```swift
struct ExerciseStats: Identifiable {
    let exerciseName: String
    let muscleGroup: MuscleGroup?
    let totalMinutes: Int
    let workoutCount: Int

    var id: String { exerciseName }
}
```

---

## Service Layer

### WorkoutLoggingService

```swift
// Protocol
protocol WorkoutLoggingService {
    func logWorkout(
        exerciseName: String,
        timerKind: TimerKind,
        durationSeconds: TimeInterval,
        repsCompleted: Int?,
        roundsCompleted: Int?
    )
}

// Implementation
final class DefaultWorkoutLoggingService: WorkoutLoggingService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) { ... }

    func logWorkout(...) {
        let log = WorkoutLog(...)
        modelContext.insert(log)
        // SwiftData auto-saves
    }
}
```

### StatsService

```swift
// Protocol
protocol StatsService {
    func totalMinutesPerDay(
        workouts: [WorkoutLog],
        period: TimePeriod
    ) -> [(date: Date, minutes: Int)]

    func groupedByExercise(
        workouts: [WorkoutLog],
        exercises: [Exercise]
    ) -> [ExerciseStats]

    func filterByPeriod(
        workouts: [WorkoutLog],
        period: TimePeriod,
        referenceDate: Date
    ) -> [WorkoutLog]
}

// Implementation
final class DefaultStatsService: StatsService { ... }
```

---

## File Structure

### New Files (8)

```
Models/
├── WorkoutLog.swift              # SwiftData @Model
└── TimePeriod.swift              # Enum + date range logic

Services/
├── WorkoutLoggingService.swift   # Protocol + DefaultWorkoutLoggingService
└── StatsService.swift            # Protocol + DefaultStatsService + ExerciseStats

Features/Stats/
├── StatsView.swift               # Main dashboard
├── WorkoutListView.swift         # Global/filtered workout list
└── ExerciseStatsCard.swift       # Per-exercise summary card

Components/
└── StatsCard.swift               # Reusable rounded card container
```

### Modified Files (6)

```
App/
├── Kraftli_TimersApp.swift       # Add WorkoutLog to schema
└── ContentView.swift             # Add Stats tab

Modifiers/
└── TimerLifecycleModifier.swift  # Add onWorkoutCompleted callback

Features/Timer/
├── Shared/TimerRunnerView.swift  # Create logging closure, pass to timer views
├── EMOM/EMOMTimerView.swift      # Accept + invoke completion callback
└── AMRAP/AMRAPTimerView.swift    # Accept + invoke completion callback
```

---

## Implementation Sequence

### Phase 1: Data Layer
**Goal**: WorkoutLog model + schema registration

1. Create `Models/WorkoutLog.swift`
   - SwiftData @Model with all properties
   - Computed properties: `timerKind`, `durationMinutes`
   - Initializer with validation

2. Create `Models/TimePeriod.swift`
   - Enum cases: week, month, year
   - `displayName` computed property
   - `dateRange(from:)` method

3. Modify `App/Kraftli_TimersApp.swift`
   - Add `WorkoutLog.self` to schema array (line 16-19)

**Test**: Build succeeds, no schema errors

### Phase 2: Service Layer
**Goal**: Logging and stats computation services

4. Create `Services/WorkoutLoggingService.swift`
   - Protocol definition
   - `DefaultWorkoutLoggingService` implementation
   - ModelContext injection

5. Create `Services/StatsService.swift`
   - Protocol definition
   - `ExerciseStats` struct
   - `DefaultStatsService` implementation
   - Methods: `filterByPeriod`, `totalMinutesPerDay`, `groupedByExercise`

**Test**: Unit test service methods with mock data

### Phase 3: Timer Integration
**Goal**: Log workouts on completion

6. Modify `Modifiers/TimerLifecycleModifier.swift`
   - Add `onWorkoutCompleted: (() -> Void)?` parameter
   - Call in `onChange(of: timer.totalTimeRemaining)` when reaches 0
   - Update view extension to accept callback

7. Modify `Features/Timer/EMOM/EMOMTimerView.swift`
   - Add `onWorkoutCompleted: (() -> Void)?` parameter
   - Pass to `.timerLifecycle()` modifier

8. Modify `Features/Timer/AMRAP/AMRAPTimerView.swift`
   - Add `onWorkoutCompleted: (() -> Void)?` parameter
   - Pass to `.timerLifecycle()` modifier

9. Modify `Features/Timer/Shared/TimerRunnerView.swift`
   - Add `@Environment(\.modelContext)`
   - Create `DefaultWorkoutLoggingService` instance
   - Create logging closure that captures preset + timer metrics
   - Pass closure to timer view constructors

**Test**: Complete EMOM/AMRAP timer → verify WorkoutLog in database

### Phase 4: Stats UI
**Goal**: Stats dashboard with chart and cards

10. Create `Components/StatsCard.swift`
    - Reusable rounded card container
    - Padding, background, corner radius
    - Match existing card styling (`.secondarySystemBackground`, 12pt corners)

11. Create `Features/Stats/ExerciseStatsCard.swift`
    - Display: exercise name, muscle group tag, total minutes, workout count
    - Uses `StatsCard` as container
    - Tap action for navigation

12. Create `Features/Stats/WorkoutListView.swift`
    - `@Query` for WorkoutLog (sorted by date descending)
    - Optional `exerciseFilter` parameter for filtered view
    - Swipe-to-delete
    - Row: date, exercise, duration, reps/rounds

13. Create `Features/Stats/StatsView.swift`
    - Time period picker (Segmented: Week/Month/Year)
    - `@Query` for WorkoutLog
    - `@Query` for Exercise (for muscle group lookup)
    - Create `DefaultStatsService`, compute stats
    - Bar chart section (Swift Charts)
    - Exercise cards section (ScrollView with LazyVStack)
    - "Show All Workouts" navigation link
    - Empty state when no workouts

14. Modify `App/ContentView.swift`
    - Add Stats tab between Timers and Settings
    - NavigationStack wrapping StatsView
    - Tab item: `Label("Stats", systemImage: "chart.bar.fill")`

**Test**: Full end-to-end flow works

---

## Data Flow

### Workout Logging Flow

```
Timer completes (totalTimeRemaining: X → 0)
    ↓
TimerLifecycleModifier.onChange detects transition
    ↓
Calls onWorkoutCompleted closure
    ↓
TimerRunnerView closure executes:
    - Reads preset: exerciseName, timerKind, duration
    - Reads timer model: completedIntervals (EMOM) / roundsCompleted (AMRAP)
    ↓
WorkoutLoggingService.logWorkout(...)
    ↓
Creates WorkoutLog, inserts into ModelContext
    ↓
SwiftData auto-saves
    ↓
Stats view @Query auto-updates
```

### Stats Display Flow

```
StatsView renders
    ↓
@Query fetches all WorkoutLog entries
@Query fetches all Exercise entries
    ↓
StatsService.filterByPeriod(workouts, period, Date())
    ↓
Filtered workouts passed to:
    - StatsService.totalMinutesPerDay() → Chart data
    - StatsService.groupedByExercise() → ExerciseStats array
    ↓
Render:
    - BarMark chart with daily/weekly totals
    - ExerciseStatsCard for each exercise
    ↓
User taps card → WorkoutListView(exerciseFilter: name)
```

---

## Key Integration Points

### TimerLifecycleModifier (lines 42-46)

Current:
```swift
.onChange(of: timer.totalTimeRemaining) { oldValue, newValue in
    if oldValue > 0 && newValue == 0 {
        session.onTimerCompleted()
    }
}
```

After:
```swift
.onChange(of: timer.totalTimeRemaining) { oldValue, newValue in
    if oldValue > 0 && newValue == 0 {
        session.onTimerCompleted()
        onWorkoutCompleted?()  // NEW
    }
}
```

### TimerRunnerView Integration

```swift
struct TimerRunnerView: View {
    let preset: TimerPreset
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            timerContent
                .navigationTitle(...)
        }
    }

    @ViewBuilder
    private var timerContent: some View {
        switch preset.kind {
        case .emom:
            EMOMTimerView(
                timerModel: EMOMTimerModel(...),
                onWorkoutCompleted: { logEMOMWorkout() }  // NEW
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(...),
                onWorkoutCompleted: { logAMRAPWorkout() }  // NEW
            )
        }
    }

    // NEW: Logging methods
    private func logEMOMWorkout() {
        let service = DefaultWorkoutLoggingService(modelContext: modelContext)
        service.logWorkout(
            exerciseName: preset.exercise?.name ?? "Unknown",
            timerKind: .emom,
            durationSeconds: preset.durationInterval,
            repsCompleted: preset.targetReps,
            roundsCompleted: nil
        )
    }

    private func logAMRAPWorkout() {
        // Similar, but need to capture roundsCompleted from timer model
        // This requires passing the model reference or extracting at call site
    }
}
```

**Note**: AMRAP rounds need to be captured from the timer model at completion time. This may require passing the timer model reference to the logging closure or restructuring slightly.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Swipe-away before completion | No log (correct - only log completed workouts) |
| No exercise selected | Use "Unknown Exercise" as name |
| App backgrounded at completion | Logging happens synchronously before background |
| Exercise deleted from library | Muscle group shows as nil (graceful degradation) |
| Duplicate exercise names | Grouped together (by design - name is the key) |

---

## Testing Strategy

### Unit Tests
- `StatsService.filterByPeriod()` - various date ranges
- `StatsService.totalMinutesPerDay()` - grouping logic
- `StatsService.groupedByExercise()` - aggregation + muscle group lookup
- `TimePeriod.dateRange()` - week/month/year boundaries

### Integration Tests
- Complete timer → WorkoutLog created
- WorkoutLog.timerKind computed property
- WorkoutLog.durationMinutes computed property

### Manual Tests
- Complete EMOM workout → verify log appears in stats
- Complete AMRAP workout → verify rounds captured
- Time period picker → chart updates
- Tap exercise card → filtered list shows correct workouts
- Delete workout → stats update
- Empty state displays when no workouts

---

## Future Extensibility

### HealthKit Integration
- `WorkoutLoggingService` can be extended with `HealthKitWorkoutLoggingService`
- Protocol abstraction allows swapping/composing implementations
- WorkoutLog can store HealthKit workout UUID for correlation

### Programs Integration
- Add optional `programId: UUID?` field to WorkoutLog
- StatsService can filter/group by program
- No schema migration needed (optional field)

### CloudKit Sync
- WorkoutLog already has UUID for sync
- SwiftData supports CloudKit with configuration change
- No model changes needed

---

## Resume Instructions

To continue implementation after context clear:

1. Read `SPEC.md` → Workout Stats section for requirements
2. Read this file (`ARCHITECTURE-workout-stats.md`) for implementation plan
3. Follow the **Implementation Sequence** phases in order
4. Each phase has a **Test** checkpoint before proceeding

Start command:
> "Implement the Workout Stats feature following ARCHITECTURE-workout-stats.md"

---

*Architecture approved: 2026-01-10*
