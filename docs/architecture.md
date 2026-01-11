# Architecture

Data models, patterns, and key components.

## Patterns

- **SwiftData** for persistence (@Model classes, @Query for fetching)
- **Observable** macro for runtime state management (timer models)
- **Dependency Injection** for testability (timer providers, audio feedback)
- **Protocol-based abstractions** for services

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
    var exercise: Exercise?       // Relationship

    // Computed
    var kind: TimerKind
    var duration: Duration
    var primaryText: String       // "EMOM · 20 min"
    var secondaryText: String     // "Exercise · 10 Reps"
}
```

### TimerKind
```swift
enum TimerKind: String, CaseIterable {
    case emom = "EMOM"
    case amrap = "AMRAP"
}
```

### Exercise (SwiftData @Model)
```swift
@Model
final class Exercise {
    var id: UUID
    var name: String
    var exerciseDescription: String?
    var formTips: [String]?
    var muscleGroup: MuscleGroup?
    var difficulty: Difficulty?
}
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
    case week, month, year
    var displayName: String
    var dateRange: (start: Date, end: Date)
    var chartGrouping: Calendar.Component
}
```

## State Management

- `@Model` for persisted data (SwiftData)
- `@Query` for reactive data fetching
- `@Observable` for runtime timer state
- `@State` for view-local state
- `@Environment(\.modelContext)` for CRUD operations
- `@MainActor` isolation for thread safety

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

### Timer Models
| Model | Purpose |
|-------|---------|
| `EMOMTimerModel` | EMOM timer logic with interval tracking (@Observable) |
| `AMRAPTimerModel` | AMRAP timer logic with round counting (@Observable) |
| `TimerSessionState` | Shared hint/confetti state management (@Observable) |

### Services
| Service | Purpose |
|---------|---------|
| `TimerCoordinator` | High-level timer orchestration |
| `TimerProvider` | Protocol for timer implementations |
| `DisplayLinkTimerProvider` | CADisplayLink for smooth animations |
| `FoundationTimerProvider` | Foundation Timer fallback |
| `AudioFeedbackProvider` | Protocol for audio feedback |
| `SystemSoundFeedback` | Production audio implementation |
| `StatsService` | Compute workout statistics |
| `WorkoutLoggingService` | Log completed workouts to SwiftData |

### UI Components
| Component | Purpose |
|-----------|---------|
| `ProgressRing` | Circular progress indicator |
| `RepsPill` | Styled capsule badge |
| `Pill` | Generic colored pill |
| `MuscleGroupTag` | Type-safe muscle group pill |
| `DifficultyIndicator` | Difficulty dot or pill |
| `ExerciseCardView` | Expandable exercise card |
| `ConfettiView` | Celebratory animation |
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
| `TimerLifecycleModifier` | Background pause, idle timer |

## Utilities

- `TimeInterval+Format` - MM:SS and HH:MM:SS formatting
- `View+ReadSize` - GeometryReader-based size measurement
- `UISeparator` - Consistent separator characters (e.g., middle dot)
- `TimePeriod+Chart` - Chart x-axis unit for time periods
- `Difficulty+UI` - Difficulty display colors
- `MuscleGroup+UI` - Muscle group display colors
- `TimerKind+UI` - Timer kind display colors
