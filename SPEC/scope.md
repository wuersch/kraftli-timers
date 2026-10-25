# Kraftli Timers - Current Scope (v1.1)

Implemented features for the current release.

## Overview

Native iOS app for high-intensity interval training. Minimalistic, distraction-free workout timers.

**Target Users**: Athletes doing short, intense workouts (20 min sessions, up to 4x per week)
**Design Principle**: Minimalistic UI with native iOS 26 components

## Feature Status

| Feature | Status | Description |
|---------|--------|-------------|
| EMOM Timer | ✅ | Interval-based workouts with automatic rep pacing |
| AMRAP Timer | ✅ | Time-based rounds, track as many as possible |
| Preset Management | ✅ | Save, edit, delete, reorder timer configurations |
| Exercise Library | ✅ | 21 curated exercises with form tips and filtering |
| Audio Feedback | ✅ | Warning beeps, interval sounds, completion cheer |
| Screen Handling | ✅ | Screen stays on, background pause/resume |
| Workout Stats | ✅ | Dashboard, charts, muscle group breakdown, per-exercise breakdown |
| Workout Logging | ✅ | Automatic logging on timer completion |
| Workout Editing | ✅ | Edit reps/rounds, delete via Edit mode |
| Settings | ✅ | Audio prefs, confetti toggle, about section, clear history |
| Launch Screen | ✅ | Animated splash with spinning arcs, toggleable in Settings |
| watchOS Companion | ✅ | Standalone timers, preset editing, CloudKit sync, haptic feedback |
| iPhone → Watch Sync | ✅ | Auto-show timer on Watch when started on iPhone |
| Synchronized Countdown | ✅ | 3-2-1-GO countdown synced between iPhone and Watch |
| HealthKit Integration | ✅ | Workouts saved to Apple Health with heart rate/calories via Watch |

## Quick Reference

### Data Models
- `TimerPreset` - Saved timer configurations (SwiftData)
- `Exercise` - Exercise metadata (SwiftData)
- `WorkoutLog` - Completed workout records (SwiftData)
- `TimerKind` - EMOM or AMRAP enum

### Key Patterns
- SwiftData `@Model` for persistence
- `@Query` for reactive data fetching
- `@Observable` for runtime timer state
- Protocol-based services for testability

### Tab Structure
1. **Timers** - Preset management and launching
2. **Stats** - Workout statistics and history
3. **Settings** - App configuration

---

## Feature Details

### EMOM Timer

Interval-based workouts where you complete exactly one rep per interval, with interval duration calculated from total duration divided by target reps.

#### Functionality
- Set total workout duration (1-60 minutes)
- Set number of target reps (automatically capped to ensure minimum 3-second intervals)
- Interval duration calculated automatically: `duration / reps`
- Each interval = one rep: complete the exercise, then rest until next interval
- Visual progress with dual concentric rings (interval + overall progress)
- Audio cues: warning beep at 3 seconds, interval completion beep, cheer on completion
- Confetti animation on workout completion

#### UI Flow
1. User taps play button on an EMOM preset
2. Full-screen timer view with dual progress rings
3. Tap anywhere to start timer
4. Warning indicator (orange) at 3 seconds remaining
5. Audio beep on each interval completion
6. "DONE" state with confetti when time reaches zero
7. Swipe down to close and return to preset list

#### Data Model
- Uses `TimerPreset` with `kind: .emom`
- Fields: `duration`, `targetReps`, `exercise`
- Interval calculation: `duration / targetReps`

---

### AMRAP Timer

Complete as many rounds as possible within a set time period.

#### Functionality
- Set total workout duration
- Choose exercise from preset list
- Manual round counter (tap to increment)
- Progress tracking with visual ring
- Cheer sound and confetti on completion

#### UI Flow
1. Tap play button on an AMRAP preset
2. Full-screen timer with single progress ring (indigo)
3. Tap anywhere to start timer
4. Tap to increment rounds (with haptic feedback)
5. Long-press (0.8s) to pause/resume
6. "DONE" state with confetti when time reaches zero

#### Data Model
- Uses `TimerPreset` with `kind: .amrap`
- Fields: `duration`, `exercise`
- Round count tracked during session (not persisted in preset)

---

### Preset Management

Save favorite timer configurations for quick access.

#### Functionality
- Create new presets via "+" button
- Edit existing presets (tap preset row in edit mode)
- Delete presets (swipe-to-delete)
- Reorder presets (Edit mode with drag handles)
- Quick-start timer from preset (tap play button)
- Default presets provided on first launch
- Persistent storage with SwiftData

#### Default Presets
- 6-Count Burpees (EMOM, 20 min, 100 reps)
- Navy Seal Burpees (EMOM, 20 min, 35 reps)
- Pull-ups (AMRAP, 20 min)
- Push-ups (EMOM, 1 min, 6 reps)

---

### Exercise Library

Curated list of exercises with detailed information.

#### Functionality
- 21 curated bodyweight exercises loaded from bundled JSON
- Rich metadata: name, description, form tips, muscle group, difficulty
- Navigation-based exercise selection with filtering
- Filter by muscle group and difficulty

#### Data Model
- `Exercise` @Model with fields: `name`, `exerciseDescription`, `formTips`, `muscleGroup`, `difficulty`
- `MuscleGroup` enum: fullBody, upperBody, lowerBody, core
- `Difficulty` enum: beginner, intermediate, advanced

---

### Workout Stats

Track completed workouts and view progress over time.

#### Functionality
- Automatic logging when timer reaches zero (swipe-away = no log)
- Stats dashboard with time period filtering (Week/Month/Year)
- Bar chart visualization (Apple Health-inspired)
- Per-exercise stats cards with tap-to-view details
- Workout log editing (reps/rounds only)
- Delete workouts via Edit mode

#### Stats Dashboard
- **Summary cards**: Total time, workout count for selected period
- **Muscle Group Card**: Statistics broken down by muscle group category
  - Groups: Full Body, Upper Body, Lower Body, Core, Cardio
  - Shows workout count and total time per muscle group
  - Color-coded indicators for visual scanning
- **Activity chart**: Bar chart showing minutes per day/week/month
  - Week: Shows all 7 days (last 7 days sliding window)
  - Month: Shows all 28 days (last 4 weeks sliding window)
  - 6 Months: Shows 6 monthly bars (last 6 months sliding window)
  - Year: Shows all 12 months (last 12 months sliding window)
- **All Workouts link**: Navigate to full workout history
- **By Exercise section**: Stats grouped by exercise, tap to view filtered list

#### Workout Log Editing
- Tap any workout row to open editor sheet
- Read-only display: date, time, exercise, duration, timer type
- Editable via picker wheel:
  - EMOM: reps completed (1-999)
  - AMRAP: rounds completed (1-99)
- Edit button in toolbar for delete functionality (swipe-to-delete)

#### UX Pattern
- **Workout logs**: Direct tap-to-edit (no competing primary action)
- **Timer presets**: Edit mode required (play button is primary action)

#### Data Logged per Workout
- Date/time of completion
- Exercise name (snapshot, not reference)
- Timer kind (EMOM/AMRAP)
- Duration (seconds)
- Reps completed (EMOM) or Rounds completed (AMRAP)

#### Data Model
```swift
@Model
final class WorkoutLog {
    var id: UUID
    var date: Date
    var exerciseName: String
    var timerKindRawValue: String
    var durationSeconds: TimeInterval
    var repsCompleted: Int?              // EMOM only
    var roundsCompleted: Int?            // AMRAP only
    var healthKitWorkoutUUID: UUID?      // Correlation with Apple Health
}
```

---

### Audio Feedback

Audio cues for workout timing without watching the screen.

#### Functionality
- Warning sound at 3 seconds before interval end
- Interval completion sound
- Workout completion sound (custom cheer, preloaded)
- Audio session configured to mix with other audio

#### Implementation
- `AudioFeedbackProvider` protocol for testability
- `SystemSoundFeedback` for production
- `SilentFeedback` for preview and silent mode (integrated into production)

---

### Screen & Background Handling

- Screen stays on during active timer (`.idleTimerDisabled`)
- An iPhone-only workout pauses when the app moves to the background
- A workout run by the Watch keeps running when the iPhone app is backgrounded or locked; the
  iPhone shows the correct time again as soon as it returns to the foreground

---

### Launch Screen

Animated splash screen displayed on app launch.

#### Functionality
- Animated splash with spinning concentric arcs
- Smooth animation on appearance
- Toggleable via "Show Animated Launch" in Settings

---

### Settings

App preferences and configuration.

#### Sections

**Audio Preferences**
- Completion sound style selector (Cheer / Neutral)

**Visual Preferences**
- Confetti toggle (on/off)
- Smooth animations toggle (on/off)
- Show animated launch toggle (on/off)

**Data Management**
- Clear workouts (with confirmation)
- Clear presets (with confirmation)
- Clear all data (with confirmation)

**About**
- App version display
- Credits and acknowledgments

---

### watchOS Companion App

Apple Watch companion for quick timer access during workouts.

#### Functionality
- Standalone timer operation (works without iPhone)
- Full preset management (create, edit, delete)
- CloudKit sync for presets with iPhone
- Haptic feedback instead of audio (wrist-friendly)
- Automatic workout logging

#### Preset Editing on Watch

Full CRUD operations for timer presets directly on Apple Watch.

**Create/Edit Features**
- Digital Crown input for duration (1-60 min) and reps
- Custom timer kind toggle (EMOM/AMRAP)
- Simple exercise list picker
- Calculated interval display for EMOM

**List Management**
- Swipe left to edit existing preset
- Swipe right to delete (with confirmation)
- "Add Preset" button at bottom of My Presets section
- Sheet-based editor presentation

**Digital Crown Integration**
- `DigitalCrownStepperView` component for numeric input
- Haptic feedback on value changes
- Smooth rotation with step increments

#### iPhone → Watch Timer Sync

When you start a timer on iPhone, it runs on your Watch too, and both show the same time.

**How It Works**
1. Start any timer on iPhone
2. The iPhone opens the Watch app and shows "Starting on Watch…" (usually under a second when the
   Watch app is open, a few seconds when it has to launch)
3. The Watch runs the workout (heart rate, calories, Apple Health save); the iPhone follows it
4. Pause, resume, rounds and stop work on either device and show up on the other
5. If the Watch doesn't answer within 5 seconds, the workout runs on iPhone only, with the
   note "Watch not available — running on iPhone"
6. Without a paired Watch (or without the Watch app), the timer starts immediately on iPhone

**While Disconnected**
- Taps on the iPhone take effect immediately and reach the Watch when it is back in range;
  a small Watch-slash icon next to the total time shows that changes are still on their way
- AMRAP rounds counted on both devices add up
- If both devices paused or resumed differently while apart, the Watch's state wins and the
  iPhone shows "Synced with Watch"

**Architecture**
- One device owns each workout's `TimerState` and publishes it; the other renders it
  (ADR-006, ADR-007)
- `TimerSessionController` on each device; `PhoneWorkoutStarter` / `WatchWorkoutStarter` run
  the start handshake
- Snapshots travel over the mirrored HealthKit session and WatchConnectivity at once

**Limitations**
- A workout started on the Watch is not shown on iPhone (backlog)
- If the Watch app starts after the 5-second timeout, it follows the iPhone's workout without
  recording heart rate

#### Synchronized Countdown

When starting a timer, both iPhone and Watch display a synchronized 3-2-1-GO countdown.

**How It Works**
1. Tap to start timer on iPhone
2. Once the Watch has confirmed (or the iPhone runs the workout alone), both devices count
   down 3-2-1-GO; the iPhone plays beeps
3. Both count down to the same start time, so the timer starts at the same instant on both
4. "Get ready" pulsing text during countdown

**Implementation**
- The owner sets the workout's `startDate` (now + 3 s); each device counts down to it
- `CountdownCoordinator` (iPhone) / `WatchCountdownCoordinator` only display the countdown
- Tapping the Watch countdown hides it; the timer still starts at the shared start time

#### Data Model
- Shares `TimerPreset`, `Exercise`, `WorkoutLog` models with iOS
- CloudKit sync for persistent data
- Timer state synced as snapshots over WatchConnectivity and the mirrored HealthKit session

---

### HealthKit Integration

Workouts are saved to Apple Health, with Watch providing heart rate and calorie data when available.

#### Workout Scenarios

| Scenario | Description | HealthKit Source |
|----------|-------------|-----------------|
| A: iPhone only | Timer on iPhone, no Watch | iPhone saves duration only |
| B: Watch only | Timer started on Watch directly | Watch saves with heart rate + calories |
| C: iPhone starts, Watch runs it | Timer started on iPhone, Watch confirms within 5 s | Watch owns the timer and saves; iPhone skips its HK save |
| D: Watch leads | Timer started on Watch, iPhone may mirror | Watch saves, iPhone receives UUID for correlation |

#### Functionality
- Workouts automatically saved to Apple Health on timer completion
- No user-facing toggle — always attempts HealthKit (graceful failure if denied)
- Watch collects heart rate and active energy via `HKLiveWorkoutBuilder`
- Workout session pauses/resumes with timer pause/resume
- iPhone-started workouts launch Watch app via `startWatchApp(toHandle:)`
- Duplicate prevention: the device that owns the workout's timer saves it to HealthKit
  (iPhone if the Watch didn't confirm in time — scenario A)
- SwiftData `WorkoutLog` correlated with HealthKit entry via UUID

#### Data Logged
- **iPhone only**: Activity type, start/end time, duration
- **With Watch**: Activity type, start/end time, duration, heart rate samples, active energy burned

#### Limitations
- iPhone-only workouts have no calorie or heart rate data
- Crash recovery is best-effort (stub implementation)
- Scenario D does not show mirrored timer UI on iPhone (Watch workout proceeds independently)

---

## UI Specification

### Tab Structure

| Tab | Purpose |
|-----|---------|
| Timers | Timer preset management and launching |
| Stats | Workout statistics and history |
| Settings | App configuration |

### Timer Preset List (Timers Tab)

- NavigationStack with "Timers" title
- Native List with preset rows
- Each row displays:
  - Primary: "EMOM · 20 min" or "AMRAP · 20 min"
  - Secondary: "Exercise · X Reps" (EMOM) or "Exercise" (AMRAP)
  - Play button (blue circle) on trailing edge
- Toolbar: Edit button (leading), Add button (trailing)
- Swipe actions: Delete
- Edit mode: Reorder with drag handles

### Preset Editor (Sheet)

- Segmented picker: EMOM / AMRAP
- Exercise selection row → opens ExerciseSelectionView
- Menu picker: Duration (1-60 minutes)
- Wheel picker: Target reps (EMOM only)
- Interval duration display
- Toolbar: Cancel (xmark) / Save (checkmark)

### EMOM Timer View (Full Screen)

- Adapts to system appearance (light/dark mode)
- Navigation title: "Exercise Name · EMOM"
- **Drag handle**: Capsule indicator for swipe-to-dismiss
- **Dual progress rings**:
  - Outer: Overall workout progress (white/gray)
  - Inner: Current interval progress (blue, orange when < 3s)
- "INTERVAL" label with large monospaced time (MM:SS)
- "TOTAL" label with total time below
- Hint text: "Tap to start" / "Tap to pause"
- **Watch sync**: "Starting on Watch…" (pulsing Watch icon) until the Watch confirms; short
  notices in the hint line ("Watch not available — running on iPhone", "Synced with Watch");
  Watch-slash icon next to the total time while changes haven't reached the Watch
- Bottom hint: "Swipe down to close"
- Confetti animation on completion
- **Gestures**: Tap to start/pause, swipe down to close
- **Responsive layout**: Scales proportionally (reference: iPhone 14 Pro @ 393pt)

### AMRAP Timer View (Full Screen)

- Adapts to system appearance (light/dark mode)
- Navigation title: "Exercise Name · AMRAP"
- **Drag handle**: Capsule indicator for swipe-to-dismiss
- **Single progress ring** (indigo)
- Large round counter in center with "ROUNDS" label
- "TOTAL" label with total time below
- Hint text: "Tap to start" / "Tap to count · Hold to pause"
- **Watch sync**: same as EMOM ("Starting on Watch…", notices, Watch-slash icon)
- Confetti animation on completion
- **Gestures**: Tap to start/increment (resume while paused), long-press to pause/resume, swipe down to close

### Stats View

- **Period picker**: Segmented control (Week/Month/6 Months/Year)
- **Summary section**: Two cards side-by-side
  - Total Time (minutes, clock icon, teal)
  - Workouts (count, flame icon, orange)
- **Muscle Group Card**: Statistics by muscle group
  - Rounded card background
  - Shows workout count and total time per muscle group
  - Color-coded indicators (Full Body, Upper Body, Lower Body, Core, Cardio)
- **Activity chart**: Bar chart with custom x-axis labels
  - Rounded card background
  - Blue gradient bars
- **All Workouts link**: Card-style navigation row
- **By Exercise section**: List of ExerciseStatsCard items
  - Each card navigates to filtered workout list
- **Empty state**: ContentUnavailableView

### Workout List Views

**WorkoutListView (Filtered by Exercise)**
- List of WorkoutRow items
- Tap row → edit sheet
- Edit button → enable swipe-to-delete

**AllWorkoutsView (Global)**
- List of WorkoutRow items
- Tap row → edit sheet
- Edit button → enable swipe-to-delete

**WorkoutRow**
- Card-style with rounded background
- Exercise name (medium weight)
- Timer kind pill (colored capsule)
- Date and summary text (secondary)

### Workout Log Editor (Sheet)

- Form with two sections:
  - **Read-only**: Date, Time, Exercise, Duration, Type (grayed values)
  - **Editable**: Picker wheel for reps (EMOM) or rounds (AMRAP)
- Toolbar: Cancel (xmark) / Save (checkmark)

### Design Principles

- Adaptive theming for timer views (respects system light/dark mode)
- Native SwiftUI components throughout
- Pill-shaped buttons and badges
- Monospaced digits for time displays
- Progress rings with smooth animations
- Accessibility labels on interactive elements
- Apple Health-inspired stats cards
