# UI Specification

The interaction design that realizes the use cases. The use cases say *what* happens; this
document records *how* it looks and is operated today (v1.6.x). Where the two disagree, the use
case wins.

## Design Principles

- Native SwiftUI components throughout (List, NavigationStack, Form, pickers)
- Dark background, minimal UI; no glass effects
- Timer screens adapt to system light/dark mode
- Pill-shaped badges, monospaced digits for times, progress rings with smooth animations
- Accessibility labels on interactive elements
- Apple Health-inspired stats cards

## iPhone

### Tab Structure

| Tab | Purpose | Use cases |
|-----|---------|-----------|
| Timers | Preset list and launching | UC-0001, UC-0002, UC-0006 |
| Stats | Stats dashboard and history | UC-0008, UC-0009 |
| Settings | Preferences, data, about | UC-0010, UC-0011 |

### Launch Screen

- Black background, two white arcs spinning in opposite directions around the app's push-up icon,
  "Kraftli Timers" fading in. Lasts 3 s and can't be skipped. Toggle: Settings → Launch Animation.

### Timer Preset List

- NavigationStack titled "Timers"; native List sorted by the athlete's order.
- Row: primary "EMOM · 20 min" / "AMRAP · 20 min"; secondary "Exercise · N Reps" (EMOM) or
  "Exercise" (AMRAP); blue play button on the trailing edge starts the workout.
- Toolbar: Edit (leading, only when presets exist), Add "+" (trailing).
- Swipe to delete (no confirmation). Edit mode: drag handles to reorder; tapping a row opens the
  editor; the play button is hidden.
- Empty state: "No Timers" — "Tap + to create your first timer".

### Preset Editor (Sheet)

- Segmented picker EMOM / AMRAP with a short description of the kind.
- Exercise row → [Exercise Selection](#exercise-selection) ("Select Exercise" if none).
- Wheel pickers: Duration (1–60 min); Total Reps (EMOM only, 1 … 20 per minute).
- Interval text: "N sec per interval" / "N min M sec per interval".
- Toolbar: Cancel (xmark) / Save (checkmark).

### Exercise Selection

- Alphabetical list of exercise cards; tapping a collapsed card selects it and returns.
- Info button expands one card at a time: description, muscle-group tag, difficulty pill, "Select".
- Filter button (filled while a filter is active) opens a half-height sheet: Muscle Group (All + 4),
  Difficulty (All + 3), "Reset" (disabled without filters), "Done". Filters combine with AND.
- Empty: "No Exercises Found" — "No exercises match your current filters." + "Clear Filters";
  without filters: "No exercises available."

### EMOM Timer

- Full screen, opens and starts the countdown immediately. Title "Exercise · EMOM".
- Drag handle (capsule); swipe down to close (ends the workout).
- Dual progress rings: outer = overall progress (white/gray); inner = interval (blue, orange in the
  last 3 s).
- Center: "INTERVAL" + large MM:SS — or "REPS current/total" with *Show Reps in Center*.
- Below: "TOTAL" + total time remaining.
- Countdown "3-2-1-GO" with a beep per count and a pulsing "Get ready".
- Tap anywhere to pause/resume; hint "Tap to pause" / "Tap to resume", hidden 5 s after start.
- Confetti for 3 s on completion (if enabled), then the [Workout Summary](#workout-summary).

### AMRAP Timer

- Like EMOM, title "Exercise · AMRAP", single indigo ring, large round counter with "ROUNDS".
- Tap to count a round (light haptic); tap while paused resumes; long-press (0.8 s) pauses/resumes
  (medium/light haptic). Hint "Tap to count · Hold to pause".

### Watch Sync Indicators

- "Starting on Watch…" with a pulsing Watch icon until the Watch confirms (swipe-down still closes).
- Short notices in the hint line (2.5 s): "Watch not available — running on iPhone",
  "Synced with Watch".
- Watch-slash icon next to TOTAL while changes haven't been confirmed by the Watch.

### Workout Summary

- Replaces the timer 0.3 s after completion: header with kind and reps/rounds; cards for Duration,
  Active Calories, Avg Heart Rate, Max Heart Rate ("--" while Watch data is pending).
- Without a Watch: footer "Connect Apple Watch for heart rate and calories".
- "Open Health" button when Health data exists. Swipe down to close.

### Stats

- Period picker (segmented): 7 Days / Month / 6 Months / Year.
- Summary cards side by side: Total Time (minutes, clock icon, teal); Workouts (count, flame icon,
  orange) with the period's unit text ("last 7 days" …).
- Muscle Group card: four columns Full / Upper / Lower / Core with time ("N min" / "N hr").
- Activity chart: blue gradient bars; x-axis weekday (7 Days), day number (Month), "Jan" (6 Months),
  "J" (Year).
- "All Workouts" card-style link; "By Exercise" cards "N min · N workouts · N reps" → filtered list
  titled with the exercise name.
- Empty state: "No Workouts Yet" — "Complete a workout to see your stats".

### Workout Lists

- WorkoutRow (card style): exercise name, kind pill, "date · N min · N reps/rounds".
- Tap row → [Workout Log Editor](#workout-log-editor). Edit button → swipe-to-delete (no confirmation).
- All Workouts empty: "No Workouts" — "Complete a workout to see it here".

### Workout Log Editor

- Sheet with a Form: read-only Date, Time, Exercise, Duration, Type (grayed); wheel for Reps
  (1–999) or Rounds (1–99). Toolbar Cancel (xmark) / Save (checkmark).

### Settings

- **Audio:** "Sound" toggle; "Cheer on Completion" toggle (only while Sound is on).
- **Visuals** (toggle cards): Launch Animation, Confetti, Smooth Animations, Show Reps in Center.
- **Manage Your Data:** Clear Workout History / Clear Timer Presets / Clear All Data, each with a
  count, disabled when empty, confirmation alert ("… This action cannot be undone."); save failure
  alert "Failed to save changes. Please try again."
- **About:** version (build), GitHub link, Privacy Policy link, Acknowledgments sheet.

## Watch App

- **Preset list:** sorted like the iPhone. Leading swipe → Edit; trailing swipe (full swipe allowed)
  → Delete without confirmation; "+" at the bottom; empty state "No presets" — "Create one to get
  started". Tapping a preset starts it.
- **Preset editor (sheet):** "Timer Type" buttons EMOM/AMRAP; Digital Crown steppers (with
  haptic detents) for duration 1–60 min and reps; interval text; "Exercise" row → flat list with
  name, muscle group and a checkmark.
- **Workout:** silent countdown with "Get ready" (tap hides it). Paged layout: controls page (End,
  Pause/Resume; resuming jumps back) to the left of the metrics page: TOTAL, INTERVAL (orange in
  the last 3 s) and REPS for EMOM / ROUNDS for AMRAP (tap to count), live heart rate and ACTIVE KCAL.
  "DONE" at the end until End is pressed. No sounds, no haptics, no confetti, no summary.
- **iPhone-started:** "Starting…" until ownership is settled.
