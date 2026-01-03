# Kraftli Timers - Specification

## Overview
Kraftli Timers is a native iOS app designed for high-intensity interval training. It provides minimalistic, distraction-free workout timers for focused fitness sessions.

**Target Users**: Athletes doing short, intense workouts (20 min sessions, up to 4x per week)
**Design Principle**: Minimalistic UI with native iOS 26 components, no unnecessary features

---

## Features

### EMOM Timer (Status: ✅ Implemented)
**User Story**: As a user, I want to perform interval-based workouts where I complete exactly one rep per interval, with the interval duration calculated from total duration divided by target reps.

**Functionality**:
- Set total workout duration (1-60 minutes)
- Set number of target reps (automatically capped to ensure minimum 3-second intervals)
- Interval duration calculated automatically: `duration / reps` (e.g., 20 min / 100 reps = 12 seconds per rep)
- Each interval = one rep: complete the exercise, then rest until the next interval begins
- Smart interval duration display with decimal formatting when needed
- Choose exercise from preset list
- Visual progress with dual concentric rings (interval + overall progress)
- Audio cues: warning beep at 3 seconds, interval completion beep, cheer sound on workout completion
- Display current interval, remaining time, and completed intervals
- Confetti animation on workout completion

**UI Flow**:
1. User opens app to Timer Presets tab
2. User taps play button on an EMOM preset (or creates new one)
3. Full-screen timer view appears showing:
   - Navigation title: "Exercise Name · EMOM"
   - Dual progress rings (interval + overall)
   - Interval countdown inside the rings
   - Total workout countdown below the rings
   - Reps completed counter (e.g., "5/100 REPS")
4. Tap anywhere to start timer
5. Both timers count down simultaneously:
   - Interval timer resets after each rep
   - Total timer counts down continuously
6. Warning indicator (orange) appears at 3 seconds remaining in interval
7. Audio beep on each interval completion
8. "DONE" state with confetti animation when total time reaches zero
9. Swipe down to close timer and return to preset list

**Data Model**:
- Uses `TimerPreset` with `kind: .emom`
- Fields: `duration`, `targetReps`, `exercise`
- Interval calculation: `duration / targetReps`

---

### AMRAP Timer (Status: ✅ Implemented)
**User Story**: As a user, I want to complete as many rounds as possible within a set time period.

**Functionality**:
- Set total workout duration
- Choose exercise from preset list
- Manual round counter (tap to increment)
- Display elapsed time and round count
- Progress tracking with visual ring
- Cheer sound and confetti animation on workout completion

**UI Flow**:
1. User taps play button on an AMRAP preset
2. Full-screen timer view appears showing:
   - Navigation title: "Exercise Name · AMRAP"
   - Single progress ring (indigo)
   - Large round counter inside the ring
   - Total workout countdown below the ring
3. Tap anywhere to start timer
4. Timer counts down continuously
5. Tap to increment rounds completed (with haptic feedback)
6. Long-press (0.8s) to pause/resume timer
7. Swipe down to close timer
8. "DONE" state with confetti animation when total time reaches zero

**Data Model**:
- Uses `TimerPreset` with `kind: .amrap`
- Fields: `duration`, `exercise`
- Round count tracked during session (not persisted in preset)

---

### Preset Management (Status: ✅ Implemented)
**User Story**: As a user, I want to save my favorite timer configurations so I can quickly start common workouts.

**Functionality**:
- ✅ Create new presets via "+" button
- ✅ Edit existing presets (tap preset row)
- ✅ Delete presets (swipe-to-delete)
- ✅ Reorder presets (Edit mode with drag handles)
- ✅ Quick-start timer from preset (tap play button)
- ✅ Default presets provided on first launch
- ✅ Persistent storage with SwiftData

**UI Flow**:
1. App opens to Timer Presets list (Timers tab)
2. Each preset shows: type + duration (primary), exercise + reps (secondary)
3. Tap "+" to create new preset via sheet
4. Tap preset row to edit via sheet
5. Swipe left to delete preset
6. Tap "Edit" to enter reorder mode
7. Tap play button to launch timer

**Data Model**:
- `TimerPreset` @Model class with SwiftData persistence
- `@Query` for automatic data fetching in views
- List shows all saved presets sorted by `sortOrder`

**Default Presets**:
- 6-Count Burpees (EMOM, 20 min, 100 reps)
- Navy Seal Burpees (EMOM, 20 min, 35 reps)
- Pull-ups (AMRAP, 20 min)
- Push-ups (EMOM, 1 min, 6 reps)

---

### Preset Persistence (Status: ✅ Implemented)
**User Story**: As a user, I want my presets to be saved when I close the app.

**Functionality**:
- ✅ Persist presets using SwiftData @Model classes
- ✅ Load saved presets on app launch via @Query
- ✅ Sync changes automatically (SwiftData auto-save)
- ✅ Default presets seeded on first launch

**Implementation**:
- `TimerPreset` and `Exercise` are SwiftData @Model classes
- Views use `@Query` for reactive data fetching
- `@Environment(\.modelContext)` for CRUD operations

---

### Exercise Library (Status: ✅ Implemented)
**User Story**: As a user, I want to choose from a curated list of exercises with detailed information to understand proper form and muscle groups targeted.

**Functionality**:
- 21 curated bodyweight exercises loaded from bundled JSON
- Rich metadata per exercise: name, description, form tips, muscle group, difficulty
- Navigation-based exercise selection with filtering
- Exercise metadata displayed in preset editor after selection

**Exercise Selection View**:
- Full-screen selection presented as sheet from preset editor
- Expandable exercise cards showing name (collapsed) or full details (expanded)
- Filter sheet for muscle group and difficulty (half-height modal)
- "All" as default filter option
- Tap card to select exercise and dismiss

**Exercise Display in Preset Editor**:
- Shows exercise name with muscle group tag and difficulty pill
- Tap to open exercise selection view

**Data Model**:
- `Exercise` @Model class with fields: `name`, `exerciseDescription`, `formTips`, `muscleGroup`, `difficulty`
- `MuscleGroup` enum: fullBody, upperBody, lowerBody, core
- `Difficulty` enum: beginner, intermediate, advanced
- Exercises loaded from `Exercises.json` via `ExerciseLoader` service
- UI colors defined in `+UI.swift` extensions (separated from domain)

---

### Audio Feedback (Status: ✅ Implemented)
**User Story**: As a user, I want audio cues to know when intervals change without watching the screen.

**Functionality**:
- Warning sound at 3 seconds before interval end
- Interval completion sound
- Workout completion sound (custom cheer, preloaded for instant playback)
- Audio session configured to mix with other audio

**Implementation**:
- `AudioFeedbackProvider` protocol for testability
- `SystemSoundFeedback` uses system sound 1057 for intervals, custom audio for completion
- `SilentFeedback` for testing without audio

---

### Screen & Background Handling (Status: ✅ Implemented)
**User Story**: As a user, I want the screen to stay on during my workout and the timer to pause if I leave the app.

**Functionality**:
- Screen sleep prevention during active timer (`.idleTimerDisabled`)
- Timer pauses when app moves to background
- Timer resumes when app returns to foreground

---

### Settings (Status: 📋 Planned)
**User Story**: As a user, I want to customize app behavior.

**Current State**: Settings tab shows "Coming soon" placeholder

**Planned Functionality**:
- Audio preferences
- Theme options
- About section (at bottom):
  - App version
  - Credits: "Icon by Guilherme Silva Soares via The Noun Project"

---

## User Interface

### Tab Structure
- **Tab 1: Timers** - Main timer preset management and launching (✅ Implemented)
- **Tab 2: Settings** - App configuration (📋 Placeholder)

### Timer Preset List (Timers Tab)
- NavigationStack with "Timers" title
- Native List component with preset rows
- Each row displays:
  - Primary text: "EMOM · 20 min" or "AMRAP · 20 min"
  - Secondary text: "Exercise · X Reps" (EMOM) or "Exercise" (AMRAP)
  - Play button (blue circle) on trailing edge
- Toolbar: Edit button (leading), Add button (trailing)
- Swipe actions: Delete
- Edit mode: Reorder with drag handles
- Dark background with rounded card-style rows

### Preset Editor (Sheet)
- Segmented picker: EMOM / AMRAP
- Exercise selection: Tap row to open ExerciseSelectionView
  - Shows selected exercise name with muscle group tag and difficulty pill
  - Chevron indicates navigation
- Menu picker: Duration (1-60 minutes)
- Wheel picker: Target reps (EMOM only, dynamic max based on 3-second minimum interval)
- Interval duration display with smart decimal formatting
- Cancel / Save buttons in toolbar

### EMOM Timer View (Full Screen Cover)
- Dark background for focus
- Exercise name + "EMOM" at top
- **Top handle bar**: Subtle capsule indicator for swipe-to-dismiss affordance
  - Turns white (.primary) while dragging, fades back after release
  - Moves with content during drag gesture
- Dual concentric progress rings:
  - Outer ring: Overall workout progress (white/gray)
  - Inner ring: Current interval progress (blue, orange when < 3s)
- "INTERVAL" label with large monospaced time display (MM:SS)
- "TOTAL" label with total time below
- Hint text inside ring: "Tap to start" / "Tap to pause" (fades after 5s, reappears on pause/completion)
- Bottom hint: "Swipe down to close" (fades after 5s, reappears on pause/completion)
- Confetti animation on completion
- Gestures: Tap anywhere to start/pause, swipe down to close
- **Responsive layout**: All UI elements scale proportionally based on available screen space
  - Uses GeometryReader with proportional sizing (reference: iPhone 14 Pro @ 393pt)
  - Vertical constraint ensures content fits in landscape (`height * 0.55`)
  - Maximum size cap (600pt) prevents oversizing on large screens

### AMRAP Timer View (Full Screen Cover)
- Dark background for focus
- Exercise name + "AMRAP" at top
- **Top handle bar**: Subtle capsule indicator for swipe-to-dismiss affordance
  - Turns white (.primary) while dragging, fades back after release
  - Moves with content during drag gesture
- Single progress ring (indigo) showing remaining time
- Large round counter in center with "ROUNDS" label
- "TOTAL" label with total time below
- Hint text inside ring: "Tap to start" / "Tap to count · Hold to pause" / "Tap to resume" (fades after 5s, reappears on pause/completion)
- Bottom hint: "Swipe down to close" (fades after 5s, reappears on pause/completion)
- Confetti animation on completion
- Gestures: Tap anywhere to start/increment/resume, long-press (0.8s) to pause, swipe down to close
- **Responsive layout**: Same proportional sizing system as EMOM

### UI Components
- `ProgressRing`: Circular progress indicator with configurable colors/sizes
- `RepsPill`: Styled capsule badge with attributed string support for responsive layouts
- `Pill`: Generic colored pill component (base for tags)
- `MuscleGroupTag`: Type-safe pill for muscle groups with size variants
- `DifficultyIndicator`: Difficulty display with dot or pill style
- `ExerciseCardView`: Expandable card for exercise selection
- `ConfettiView`: Celebratory animation with 120 colored pieces
- `ComingSoonView`: Reusable placeholder for unimplemented features

### Design Implemented
- Dark backgrounds for timer views
- Native SwiftUI components throughout
- Pill-shaped buttons and badges
- Monospaced digits for time displays
- Progress rings with smooth animations
- Accessibility labels on interactive elements

---

## Data Models

### TimerPreset (SwiftData @Model)
```swift
@Model
final class TimerPreset {
    var id: UUID
    var kindRawValue: String      // Stored as string for SwiftData
    var durationInterval: TimeInterval  // Seconds
    var targetReps: Int?          // Optional, only for EMOM
    var sortOrder: Int            // For list ordering
    var exercise: Exercise?       // Relationship

    // Computed properties
    var kind: TimerKind           // Parsed from kindRawValue
    var duration: Duration        // Computed from durationInterval
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

### MuscleGroup
```swift
enum MuscleGroup: String, Codable, CaseIterable {
    case fullBody, upperBody, lowerBody, core
    var displayName: String  // Human-readable
    var color: Color         // UI extension (teal, indigo, blue, purple)
}
```

### Difficulty
```swift
enum Difficulty: String, Codable, CaseIterable {
    case beginner, intermediate, advanced
    var displayName: String  // Human-readable
    var color: Color         // UI extension (green, orange, red)
}
```

---

## Architecture

### Pattern
- **SwiftData** for persistence (@Model classes, @Query for fetching)
- **Observable** macro for runtime state management (timer models)
- **Dependency Injection** for testability (timer providers, audio feedback)
- **Protocol-based abstractions** for services
- Views are composable and focused

### Key Components

**Views**:
- `ContentView`: Tab-based navigation container
- `TimerPresetView`: Preset list with CRUD operations
- `TimerPresetEditorView`: Create/edit preset sheet
- `ExerciseSelectionView`: Exercise browser with filtering
- `ExerciseFilterSheet`: Half-height filter modal
- `EMOMTimerView`: Full-screen EMOM timer interface
- `AMRAPTimerView`: Full-screen AMRAP timer
- `ComingSoonView`: Reusable placeholder view

**UI Components**:
- `ProgressRing`: Circular progress indicator with configurable colors/sizes
- `RepsPill`: Styled capsule badge with attributed string support
- `Pill`: Generic colored pill (base component)
- `MuscleGroupTag`: Type-safe muscle group pill
- `DifficultyIndicator`: Difficulty dot or pill
- `ExerciseCardView`: Expandable exercise card
- `ConfettiView`: Celebratory animation with 120 pieces

**Models**:
- `TimerPreset`: SwiftData @Model for preset persistence
- `Exercise`: SwiftData @Model for exercise data (v2+ ready)
- `TimerKind`: Enum for timer types (EMOM/AMRAP)
- `EMOMTimerModel`: EMOM timer logic with interval tracking (@Observable)
- `AMRAPTimerModel`: AMRAP timer logic with round counting (@Observable)
- `TimerSessionState`: Shared hint/confetti state management (@Observable)

**Services**:
- `TimerCoordinator`: High-level timer orchestration
- `TimerProvider` protocol with implementations:
  - `DisplayLinkTimerProvider`: CADisplayLink for smooth animations (default)
  - `FoundationTimerProvider`: Foundation Timer fallback
- `AudioFeedbackProvider` protocol with implementations:
  - `SystemSoundFeedback`: Production audio
  - `SilentFeedback`: Testing without audio

### State Management
- `@Model` for persisted data (SwiftData)
- `@Query` for reactive data fetching from SwiftData
- `@Observable` for runtime timer state
- `@State` for view-local state
- `@Environment(\.modelContext)` for CRUD operations
- `@MainActor` isolation for thread safety

### Utilities
- `TimeInterval+Format`: Extensions for MM:SS and HH:MM:SS formatting
- `View+ReadSize`: GeometryReader-based size measurement
- `WorkoutTimer` protocol: Common timer interface

### Shared Components
- `DragHandleView`: Reusable drag handle for swipe-to-dismiss
- `SwipeHintOverlay`: "Swipe down to close" hint overlay
- `SwipeToDismissModifier`: ViewModifier for swipe gesture handling
- `TimerLifecycleModifier`: ViewModifier for timer lifecycle (background pause, idle timer)

---

## v1 Remaining Work

### Must Complete
- [x] AMRAP Timer UI (implemented with single indigo ring, tap-to-count gestures)
- [x] Preset Persistence with SwiftData (@Model classes, @Query)
- [ ] Settings screen implementation

---

## Future Considerations (v2+)

### Form Tips During Workout (Status: 🔮 Future)
**User Story**: As a user, I want to see form tips when I pause the timer to remind me of proper technique.

**Functionality**:
- Display form tips overlay when timer is paused
- Minimalist presentation that doesn't distract from workout focus
- Uses existing `formTips` data from Exercise model

**Priority**: Low (nice-to-have enhancement)

---

### Programs (Status: 🔮 Future)
**User Story**: As a user, I want to combine timer presets into structured training programs with scheduling and progression.

**Use Cases**:
- Simple rotation: 4x/week, alternate between exercises
- Weekly progression: Month-long program with increasing difficulty
- Mixed workouts: Combine EMOM and AMRAP in a single session

**Functionality**:
- Create programs from existing presets
- Define schedule (times per week, specific days)
- Organize into phases with progression
- Track active program and next workout
- Visual progress: "Step 1/4", "Week 3/8"

**Data Model** (Draft):
```swift
struct Program: Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let schedule: Schedule
    let phases: [ProgramPhase]
}

struct ProgramPhase: Identifiable {
    let id: UUID
    let name: String              // e.g., "Week 1-2"
    let workouts: [ProgramWorkout]
}
```

**Priority**: 2 (builds on Exercise Library)

---

### watchOS Companion App (Status: 🔮 Future)
**User Story**: As a user, I want to run my timers from my Apple Watch without needing my phone nearby.

**Functionality**:
- List timer presets synced from iPhone
- Default timer available for standalone mode (App Store compliance - must work without iPhone)
- Run timers with simplified UI:
  - Show rings and content only (no total time display)
  - Haptic feedback instead of audio (Watch speaker limitations)
- Run-only interactions (no preset creation/editing on Watch)

**Data Sync**:
- **Watch Connectivity**: Real-time sync when iPhone is nearby
- **CloudKit/iCloud**: Background sync for standalone operation
- Presets sync automatically; Watch always has latest data

**Smart Remote Control**:
- Starting timer on Watch controls iPhone only if:
  - iPhone app is active/unlocked
  - Prevents unwanted timer starts when phone is left at home
- Independent operation when iPhone unavailable

**Technical Notes**:
- Reuse timer models (EMOMTimerModel, AMRAPTimerModel) - same logic, different UI
- Use FoundationTimerProvider (CADisplayLink unavailable on watchOS)
- SwiftData works on watchOS 10.4+ with shared CloudKit container

**Priority**: 2.5 (fits between Programs and Workout History; requires HealthKit for full value)

---

### Workout History & Stats (Status: 🔮 Future)
**User Story**: As a user, I want to track my completed workouts and see my progress over time.

**Functionality**:
- Log completed workouts (date, duration, exercise, rounds/reps)
- Stats views: daily, weekly, monthly overviews
- Program progress visualization (timeline, milestones)
- Celebration moments for achievements

**Data Model** (Draft):
```swift
struct WorkoutLog: Identifiable {
    let id: UUID
    let date: Date
    let preset: TimerPreset
    let programId: UUID?
    let duration: Duration
    let roundsCompleted: Int?
    let caloriesEstimate: Double?
}
```

**Priority**: 3 (tracking layer)

---

### AI-Assisted Program Generation (Status: 🔮 Future)
**User Story**: As a user, I want to generate personalized training programs based on my fitness level and goals.

**Functionality**:
- Short conversational flow to gather user context:
  - Current fitness level
  - Training goals (strength, endurance, etc.)
  - Available days per week
  - Session duration preference
- On-device AI generates personalized program
- User can review, tweak, and save

**Technical Approach**:
- Apple Foundation Models (iOS 26+) - free, on-device, private
- `@Generable` macro for structured output matching app's data model
- `@Guide` constraints to use only curated exercises

**Dependencies**: Requires Exercise Library and Programs features

**Priority**: 4 (personalization layer)

---

### HealthKit Integration (Status: 🔮 Future)
**User Story**: As a user, I want my workouts synced with Apple Health and see real-time heart rate during training.

**Functionality**:

**Write to HealthKit**:
- Record completed workouts to HealthKit
  - Duration, workout type, estimated calories
  - Enables rewards in apps like H+ (health insurance bonus)
- Read active calorie data to refine per-exercise estimates

**Live Heart Rate Display** (requires Apple Watch):
- Show real-time heart rate on iPhone/iPad timer screen during workouts
- UI: Small beating/pulsing heart icon (top right corner) with BPM number below
- Streams from Watch via HealthKit workout session
- Graceful degradation: hidden if no Watch or heart rate unavailable

**Post-Workout Summary Screen**:
- Appears after timer completes (before/alongside confetti)
- Stats displayed:
  - Duration
  - Reps completed (EMOM) / Rounds completed (AMRAP)
  - Heart rate: min / avg / max (if available)
  - Calories burned
- Provides tangible feedback and sense of accomplishment

**Programs Integration**:
- Single HealthKit workout session spans entire program (all exercises)
- No summary interruptions between exercises - quick visual transition only
- Summary screen appears only after final exercise in program
- Standalone timers (not in program) show summary immediately after completion

**Priority**: Can be implemented alongside Workout History

---

### Other Ideas
- [ ] Rest periods between intervals
- [ ] Custom audio cues
- [ ] Tabata timer mode

---

## Status Legend
- ✅ **Implemented**: Feature is complete and tested
- 🚧 **In Progress**: Currently being developed
- 📋 **Planned**: Documented but not yet started
- 🔮 **Future**: Under consideration for later versions

---

*Last Updated: 2026-01-03 (Implemented Exercise Selection with filtering, expandable cards, muscle group/difficulty tags, and Pill component architecture)*
