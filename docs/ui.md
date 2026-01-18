# UI Specification

Interface design and component specifications.

## Tab Structure

| Tab | Purpose | Status |
|-----|---------|--------|
| Timers | Timer preset management and launching | ✅ |
| Stats | Workout statistics and history | ✅ |
| Settings | App configuration | ✅ Implemented |

## Timer Preset List (Timers Tab)

- NavigationStack with "Timers" title
- Native List with preset rows
- Each row displays:
  - Primary: "EMOM · 20 min" or "AMRAP · 20 min"
  - Secondary: "Exercise · X Reps" (EMOM) or "Exercise" (AMRAP)
  - Play button (blue circle) on trailing edge
- Toolbar: Edit button (leading), Add button (trailing)
- Swipe actions: Delete
- Edit mode: Reorder with drag handles

## Preset Editor (Sheet)

- Segmented picker: EMOM / AMRAP
- Exercise selection row → opens ExerciseSelectionView
- Menu picker: Duration (1-60 minutes)
- Wheel picker: Target reps (EMOM only)
- Interval duration display
- Toolbar: Cancel (xmark) / Save (checkmark)

## EMOM Timer View (Full Screen)

- Adapts to system appearance (light/dark mode)
- Navigation title: "Exercise Name · EMOM"
- **Drag handle**: Capsule indicator for swipe-to-dismiss
- **Dual progress rings**:
  - Outer: Overall workout progress (white/gray)
  - Inner: Current interval progress (blue, orange when < 3s)
- "INTERVAL" label with large monospaced time (MM:SS)
- "TOTAL" label with total time below
- Hint text: "Tap to start" / "Tap to pause"
- Bottom hint: "Swipe down to close"
- Confetti animation on completion
- **Gestures**: Tap to start/pause, swipe down to close
- **Responsive layout**: Scales proportionally (reference: iPhone 14 Pro @ 393pt)

## AMRAP Timer View (Full Screen)

- Adapts to system appearance (light/dark mode)
- Navigation title: "Exercise Name · AMRAP"
- **Drag handle**: Capsule indicator for swipe-to-dismiss
- **Single progress ring** (indigo)
- Large round counter in center with "ROUNDS" label
- "TOTAL" label with total time below
- Hint text: "Tap to start" / "Tap to count · Hold to pause"
- Confetti animation on completion
- **Gestures**: Tap to start/increment, long-press to pause, swipe down to close

## Stats View

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

## Workout List Views

### WorkoutListView (Filtered by Exercise)
- List of WorkoutRow items
- Tap row → edit sheet
- Edit button → enable swipe-to-delete

### AllWorkoutsView (Global)
- List of WorkoutRow items
- Tap row → edit sheet
- Edit button → enable swipe-to-delete

### WorkoutRow
- Card-style with rounded background
- Exercise name (medium weight)
- Timer kind pill (colored capsule)
- Date and summary text (secondary)

## Workout Log Editor (Sheet)

- Form with two sections:
  - **Read-only**: Date, Time, Exercise, Duration, Type (grayed values)
  - **Editable**: Picker wheel for reps (EMOM) or rounds (AMRAP)
- Toolbar: Cancel (xmark) / Save (checkmark)

## Design Principles

- Adaptive theming for timer views (respects system light/dark mode)
- Native SwiftUI components throughout
- Pill-shaped buttons and badges
- Monospaced digits for time displays
- Progress rings with smooth animations
- Accessibility labels on interactive elements
- Apple Health-inspired stats cards
