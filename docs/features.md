# Features

Detailed documentation for all implemented features.

## EMOM Timer

**Status**: ✅ Implemented

Interval-based workouts where you complete exactly one rep per interval, with interval duration calculated from total duration divided by target reps.

### Functionality
- Set total workout duration (1-60 minutes)
- Set number of target reps (automatically capped to ensure minimum 3-second intervals)
- Interval duration calculated automatically: `duration / reps`
- Each interval = one rep: complete the exercise, then rest until next interval
- Visual progress with dual concentric rings (interval + overall progress)
- Audio cues: warning beep at 3 seconds, interval completion beep, cheer on completion
- Confetti animation on workout completion

### UI Flow
1. User taps play button on an EMOM preset
2. Full-screen timer view with dual progress rings
3. Tap anywhere to start timer
4. Warning indicator (orange) at 3 seconds remaining
5. Audio beep on each interval completion
6. "DONE" state with confetti when time reaches zero
7. Swipe down to close and return to preset list

### Data Model
- Uses `TimerPreset` with `kind: .emom`
- Fields: `duration`, `targetReps`, `exercise`
- Interval calculation: `duration / targetReps`

---

## AMRAP Timer

**Status**: ✅ Implemented

Complete as many rounds as possible within a set time period.

### Functionality
- Set total workout duration
- Choose exercise from preset list
- Manual round counter (tap to increment)
- Progress tracking with visual ring
- Cheer sound and confetti on completion

### UI Flow
1. Tap play button on an AMRAP preset
2. Full-screen timer with single progress ring (indigo)
3. Tap anywhere to start timer
4. Tap to increment rounds (with haptic feedback)
5. Long-press (0.8s) to pause/resume
6. "DONE" state with confetti when time reaches zero

### Data Model
- Uses `TimerPreset` with `kind: .amrap`
- Fields: `duration`, `exercise`
- Round count tracked during session (not persisted in preset)

---

## Preset Management

**Status**: ✅ Implemented

Save favorite timer configurations for quick access.

### Functionality
- Create new presets via "+" button
- Edit existing presets (tap preset row in edit mode)
- Delete presets (swipe-to-delete)
- Reorder presets (Edit mode with drag handles)
- Quick-start timer from preset (tap play button)
- Default presets provided on first launch
- Persistent storage with SwiftData

### Default Presets
- 6-Count Burpees (EMOM, 20 min, 100 reps)
- Navy Seal Burpees (EMOM, 20 min, 35 reps)
- Pull-ups (AMRAP, 20 min)
- Push-ups (EMOM, 1 min, 6 reps)

---

## Exercise Library

**Status**: ✅ Implemented

Curated list of exercises with detailed information.

### Functionality
- 21 curated bodyweight exercises loaded from bundled JSON
- Rich metadata: name, description, form tips, muscle group, difficulty
- Navigation-based exercise selection with filtering
- Filter by muscle group and difficulty

### Data Model
- `Exercise` @Model with fields: `name`, `exerciseDescription`, `formTips`, `muscleGroup`, `difficulty`
- `MuscleGroup` enum: fullBody, upperBody, lowerBody, core
- `Difficulty` enum: beginner, intermediate, advanced

---

## Workout Stats

**Status**: ✅ Implemented

Track completed workouts and view progress over time.

### Functionality
- Automatic logging when timer reaches zero (swipe-away = no log)
- Stats dashboard with time period filtering (Week/Month/Year)
- Bar chart visualization (Apple Health-inspired)
- Per-exercise stats cards with tap-to-view details
- Workout log editing (reps/rounds only)
- Delete workouts via Edit mode

### Stats Dashboard
- **Summary cards**: Total time, workout count for selected period
- **Activity chart**: Bar chart showing minutes per day/month
  - Week: Shows all 7 weekdays (Mon-Sun)
  - Month: Shows days with automatic label spacing
  - Year: Shows all 12 months (J, F, M, A, M, J, J, A, S, O, N, D)
- **All Workouts link**: Navigate to full workout history
- **By Exercise section**: Stats grouped by exercise, tap to view filtered list

### Workout Log Editing
- Tap any workout row to open editor sheet
- Read-only display: date, time, exercise, duration, timer type
- Editable via picker wheel:
  - EMOM: reps completed (1-999)
  - AMRAP: rounds completed (1-99)
- Edit button in toolbar for delete functionality (swipe-to-delete)

### UX Pattern
- **Workout logs**: Direct tap-to-edit (no competing primary action)
- **Timer presets**: Edit mode required (play button is primary action)

### Data Logged per Workout
- Date/time of completion
- Exercise name (snapshot, not reference)
- Timer kind (EMOM/AMRAP)
- Duration (seconds)
- Reps completed (EMOM) or Rounds completed (AMRAP)

### Data Model
```swift
@Model
final class WorkoutLog {
    var id: UUID
    var date: Date
    var exerciseName: String
    var timerKindRawValue: String
    var durationSeconds: TimeInterval
    var repsCompleted: Int?      // EMOM only
    var roundsCompleted: Int?    // AMRAP only
}
```

---

## Audio Feedback

**Status**: ✅ Implemented

Audio cues for workout timing without watching the screen.

### Functionality
- Warning sound at 3 seconds before interval end
- Interval completion sound
- Workout completion sound (custom cheer, preloaded)
- Audio session configured to mix with other audio

### Implementation
- `AudioFeedbackProvider` protocol for testability
- `SystemSoundFeedback` for production
- `SilentFeedback` for testing

---

## Screen & Background Handling

**Status**: ✅ Implemented

- Screen stays on during active timer (`.idleTimerDisabled`)
- Timer pauses when app moves to background
- Timer resumes when app returns to foreground

---

## Settings

**Status**: 📋 Planned

Currently shows "Coming soon" placeholder.

### Planned
- Audio preferences
- Theme options
- About section with app version and credits
