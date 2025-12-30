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
- Audio cues: warning beep at 3 seconds, interval completion beep, triple beep on workout completion
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
9. Long-press (0.8s) to close timer and return to preset list

**Data Model**:
- Uses `TimerPreset` with `kind: .emom`
- Fields: `duration`, `targetReps`, `exercise`
- Interval calculation: `duration / targetReps`

---

### AMRAP Timer (Status: 🚧 In Progress)
**User Story**: As a user, I want to complete as many rounds as possible within a set time period.

**Functionality**:
- Set total workout duration
- Choose exercise from preset list
- Manual round counter (tap to increment)
- Display elapsed time and round count
- Progress tracking

**Implementation Status**:
- ✅ Model complete (`AMRAPTimerModel` with countdown, round tracking, pause/resume)
- 📋 UI shows "Coming soon" placeholder - needs implementation

**UI Flow** (Planned):
1. User taps play button on an AMRAP preset
2. Full-screen timer view appears
3. User taps to start timer
4. Timer counts down to zero
5. User taps to increment rounds completed
6. Summary shows total rounds and time

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

**UI Flow**:
1. App opens to Timer Presets list (Timers tab)
2. Each preset shows: type + duration (primary), exercise + reps (secondary)
3. Tap "+" to create new preset via sheet
4. Tap preset row to edit via sheet
5. Swipe left to delete preset
6. Tap "Edit" to enter reorder mode
7. Tap play button to launch timer

**Data Model**:
- `TimerPreset` managed by `TimerPresetStore` (Observable)
- In-memory storage currently (SwiftData persistence planned)
- List shows all saved presets

**Default Presets**:
- 6-Count Burpees (EMOM, 20 min, 100 reps)
- Navy Seal Burpees (EMOM, 20 min, 35 reps)
- Pull-ups (AMRAP, 20 min)
- Push-ups (EMOM, 1 min, 6 reps)

---

### Preset Persistence (Status: 📋 Planned)
**User Story**: As a user, I want my presets to be saved when I close the app.

**Functionality**:
- Persist presets using SwiftData
- Load saved presets on app launch
- Sync changes automatically

**Implementation Status**:
- ✅ SwiftData schema configured
- 📋 Persistence not yet active (currently in-memory only)

---

### Exercise Library (Status: ✅ Implemented)
**User Story**: As a user, I want to choose from a predefined list of common exercises.

**Functionality**:
- Predefined exercise list
- Menu picker for exercise selection in preset editor
- Display exercise name in timer and preset list

**Current Exercise List**:
- Pull-ups
- 6-Count Burpees
- Navy Seal Burpees
- Push-ups

**Data Model**:
- `Exercise` struct with `name` field
- Static `availableExercises` array

---

### Audio Feedback (Status: ✅ Implemented)
**User Story**: As a user, I want audio cues to know when intervals change without watching the screen.

**Functionality**:
- Warning sound at 3 seconds before interval end
- Interval completion sound
- Workout completion sound (triple beep sequence)
- Audio session configured to mix with other audio

**Implementation**:
- `AudioFeedbackProvider` protocol for testability
- `SystemSoundFeedback` uses system sound 1057
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
- About/version info

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
- Menu picker: Exercise selection
- Menu picker: Duration (1-60 minutes)
- Wheel picker: Target reps (EMOM only, dynamic max based on 3-second minimum interval)
- Interval duration display with smart decimal formatting
- Cancel / Save buttons in toolbar

### EMOM Timer View (Full Screen Cover)
- Dark background for focus
- Exercise name + "EMOM" at top
- Dual concentric progress rings:
  - Outer ring: Overall workout progress (white/gray)
  - Inner ring: Current interval progress (blue, orange when < 3s)
- "INTERVAL" label with large monospaced time display (MM:SS)
- "TOTAL" label with total time below
- Hint text: "Tap to start · Hold to close" / "Tap to pause · Hold to close"
- Confetti animation on completion
- Gestures: Tap to start/pause, long-press (0.8s) to close
- **Responsive layout**: All UI elements scale proportionally based on available screen space
  - Uses GeometryReader with proportional sizing (reference: iPhone 14 Pro @ 393pt)
  - Vertical constraint ensures content fits in landscape (`height * 0.55`)
  - Maximum size cap (600pt) prevents oversizing on large screens

### AMRAP Timer View (Full Screen Cover)
- Currently shows "Coming soon" placeholder
- Planned: countdown display, round counter, tap-to-increment

### UI Components
- `ProgressRing`: Circular progress indicator with configurable colors/sizes
- `RepsPill`: Styled capsule badge with configurable font size for responsive layouts
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

### TimerPreset
```swift
struct TimerPreset: Identifiable, Equatable {
    let id: UUID
    let kind: TimerKind
    let duration: Duration        // Total workout duration
    let targetReps: Int?          // Optional, only for EMOM
    let exercise: Exercise

    // Computed properties
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

### Exercise
```swift
struct Exercise: Equatable, Hashable {
    let name: String

    static let availableExercises: [Exercise]
}
```

---

## Architecture

### Pattern
- **Observable** macro for state management (modern SwiftUI)
- **Dependency Injection** for testability (timer providers, audio feedback)
- **Protocol-based abstractions** for services
- Views are composable and focused
- SwiftData schema prepared (not yet persisted)

### Key Components

**Views**:
- `ContentView`: Tab-based navigation container
- `TimerPresetView`: Preset list with CRUD operations
- `TimerPresetEditorView`: Create/edit preset sheet
- `EMOMTimerView`: Full-screen EMOM timer interface
- `AMRAPTimerView`: Full-screen AMRAP timer (placeholder)
- `ComingSoonView`: Reusable placeholder view

**UI Components**:
- `ProgressRing`: Circular progress indicator with configurable colors/sizes
- `RepsPill`: Styled capsule badge with attributed string support
- `ConfettiView`: Celebratory animation with 120 pieces

**Models**:
- `EMOMTimerModel`: EMOM timer logic with interval tracking (@Observable)
- `AMRAPTimerModel`: AMRAP timer logic with round counting (@Observable)
- `TimerPresetStore`: Observable store for preset management

**Services**:
- `TimerCoordinator`: High-level timer orchestration
- `TimerProvider` protocol with implementations:
  - `DisplayLinkTimerProvider`: CADisplayLink for smooth animations (default)
  - `FoundationTimerProvider`: Foundation Timer fallback
- `AudioFeedbackProvider` protocol with implementations:
  - `SystemSoundFeedback`: Production audio
  - `SilentFeedback`: Testing without audio

### State Management
- `@Observable` for models and stores
- `@State` for view-local state
- `@Environment` for dependency injection
- `@MainActor` isolation for thread safety

### Utilities
- `TimeInterval+Format`: Extensions for MM:SS and HH:MM:SS formatting
- `View+ReadSize`: GeometryReader-based size measurement
- `WorkoutTimer` protocol: Common timer interface

---

## v1 Remaining Work

### Must Complete
- [ ] AMRAP Timer UI (model exists, need view implementation)
- [ ] Preset Persistence with SwiftData
- [ ] Settings screen implementation

---

## Future Considerations (v2+)

### Exercise Library Expansion (Status: 🔮 Future)
**User Story**: As a user, I want detailed information about exercises to understand proper form and expected benefits.

**Functionality**:
- Expand from 4 to ~20 curated bodyweight exercises
- Rich metadata per exercise:
  - Description and form tips
  - Muscle groups targeted
  - Calorie burn estimates (range)
  - Difficulty level (beginner/intermediate/advanced)
- Exercise browser with filtering by muscle group
- Display metadata in preset editor (not during workout - no distractions)

**Data Model** (Draft):
```swift
struct Exercise: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let muscleGroups: [MuscleGroup]
    let caloriesPerMinute: ClosedRange<Double>
    let difficulty: Difficulty
}
```

**Priority**: 1 (foundation for other features)

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
**User Story**: As a user, I want my workouts synced with Apple Health so other apps (like H+) can see my activity.

**Functionality**:
- **Write**: Record completed workouts to HealthKit
  - Duration, workout type, estimated calories
  - Enables rewards in apps like H+ (health insurance bonus)
- **Read**: Import active calorie data to refine per-exercise estimates

**Priority**: Can be implemented alongside Workout History

---

### Other Ideas
- [ ] Rest periods between intervals
- [ ] Custom audio cues
- [ ] Apple Watch companion app
- [ ] Tabata timer mode

---

## Status Legend
- ✅ **Implemented**: Feature is complete and tested
- 🚧 **In Progress**: Currently being developed
- 📋 **Planned**: Documented but not yet started
- 🔮 **Future**: Under consideration for later versions

---

*Last Updated: 2025-12-30*
