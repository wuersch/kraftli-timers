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
| Timers | Preset list and launching | UC-0001, UC-0002, UC-0006, UC-0012 |
| Training | Week plan and sessions | UC-0013, UC-0014 |
| Stats | Stats dashboard and history | UC-0008, UC-0009 |
| Settings | Preferences, data, about | UC-0010, UC-0011 |

### Launch Screen

- Black background, two white arcs spinning in opposite directions around the app's push-up icon,
  "Kraftli Timers" fading in. Lasts 3 s and can't be skipped. Toggle: Settings → Launch Animation.

### Timer Preset List

- NavigationStack titled "Timers"; native List sorted by the athlete's order.
- Row: primary "EMOM · 20 min" / "AMRAP · 20 min" / "For Time"; secondary "Exercise · N Reps"
  (EMOM, For Time) or "Exercise" (AMRAP); blue play button on the trailing edge starts the workout.
- Toolbar: Edit (leading, only when presets exist), Add "+" (trailing).
- Swipe to delete (no confirmation). Edit mode: drag handles to reorder; tapping a row opens the
  editor; the play button is hidden.
- Empty state: "No Timers" — "Tap + to create your first timer".

### Preset Editor (Sheet)

- Segmented picker EMOM / AMRAP / For Time with a short description of the kind.
- Exercise row → [Exercise Selection](#exercise-selection) ("Select Exercise" if none).
- Wheel pickers: Duration (1–60 min; not for For Time); Total Reps (EMOM: 1 … 20 per minute;
  For Time: 1–999, default 100).
- Interval text (EMOM): "N sec per interval" / "N min M sec per interval".
- Toolbar: Cancel (xmark) / Save (checkmark).
- While the exercise is a hold (Plank, Wall Sit), For Time can't be selected; the footnote
  "Exercise is a hold. For Time needs an exercise counted in reps." says why.

### Exercise Selection

- Holds aren't listed while the kind is For Time.

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

### For Time Timer

- Like AMRAP, title "Exercise · For Time", teal. A comet (solid round head, fading tail) circles
  the ring continuously, one lap per 10 s like a stopwatch hand; it freezes while paused
  and closes into a full ring when done.
- Center: "REPS" + large target rep count.
- Below: "ELAPSED" + elapsed time counting up; after done, "FINISH TIME".
- No signals during the workout.
- Tap = done (no confirmation; ignored during the countdown); tap while paused resumes; long-press
  (0.8 s) pauses/resumes. Hint "Tap when done · Hold to pause" / "Tap to resume".

### Watch Sync Indicators

- "Starting on Watch…" with a pulsing Watch icon until the Watch confirms (swipe-down still closes).
- Short notices in the hint line (2.5 s): "Watch not available — running on iPhone",
  "Synced with Watch".
- Watch-slash icon next to TOTAL while changes haven't been confirmed by the Watch.

### Workout Summary

- Replaces the timer 0.3 s after completion: header with kind and reps/rounds; cards for Duration
  (For Time: "Finish Time" M:SS and pace "N.N s/rep"), Active Calories, Avg Heart Rate, Max Heart Rate ("--" while Watch data is pending).
- Without a Watch: footer "Connect Apple Watch for heart rate and calories".
- "Open Health" button when Health data exists. Swipe down to close.

### Training

- NavigationStack titled "Training", second tab. Toolbar: Add "+" (trailing) opens the
  [Session Editor](#session-editor-sheet) for a new session.
- **Session shape:** wherever a session appears, it is drawn as a bar of segments, one per timer
  in running order (loops unrolled), coloured by kind (EMOM blue, AMRAP indigo, For Time teal,
  rest gray) and sized by duration; For Time uses its estimate. Segments are separated by a small
  gap, which is dropped when a session has more segments than fit with it.
- **Week strip:** seven day tiles side by side, starting with the region's first weekday, labelled
  "Mon" … "Sun". A training day's tile shows its session's shape as a vertical stack; a rest day
  is an empty dashed outline. Today's label is a white pill. Tapping a tile selects the day
  (white ring); today is selected when the tab opens.
- **Selected day, with a session:** card with "TODAY · TUESDAY" (or just the weekday), the session
  name, "≈ N min · N timers", the shape as a bar with a bracket under each loop, and the timers as
  rows: kind colour, exercise, "5 min · 50 reps" / "4 min" / "30 reps · ≈ 4 min"; a loop's rows sit
  next to "N×" and end with "Rest · 1 min". "Change" opens a sheet with the session cards,
  the current one checked, and "Rest day". Swipe left on the card: "Remove" (gray, no
  confirmation) makes the day a rest day; the session itself stays.
- **Selected day, rest:** "Rest day" — "Tap + on a session to train on Wednesdays." While a rest
  day is selected, each session card below carries a "+" that plans it on that day.
- **Sessions:** below the selected day, one card per session in alphabetical order: name, shape,
  "≈ N min", followed by the days it is planned on ("≈ 37 min · Mon, Thu"). Tap opens the [Session Editor](#session-editor-sheet). Swipe to delete, with a
  confirmation alert: "Delete "Name"?" — "It is also removed from your week. This action cannot be
  undone." Long-press menu: Duplicate (opens the editor on a copy named "Name 2", "Name 3" …), Delete.
- Empty state (no sessions; the week strip is hidden): "No Sessions" — "Compose a session first,
  then plan it on your training days." + "New Session".

### Session Editor (Sheet)

- Toolbar: Cancel (xmark) / Save (checkmark); Save is always enabled.
- Name as a large title field (placeholder "Session Name"), below it "≈ N min · N timers" and the
  session shape, both updating with every change.
- **Blocks:** stacked without gaps, like a structogram, in running order.
  - Timer block, tinted by kind: kind in small caps, exercise name; trailing "5 min" + "50 reps"
    (EMOM), "4 min" (AMRAP), "30 reps" + "≈ 4 min" (For Time). Tap opens the
    [Step Editor](#step-editor-sheet).
  - Loop block: a rail on the leading edge with a repeat icon and "3×" that spans the loop's
    timer blocks, "+ Timer in loop", and a row "Rest between rounds" with "None" or the time.
    Tapping the rail or the rest row opens a "Loop" sheet: wheel for the rounds (2–20), wheels
    for the rest (0–10 min, seconds in steps of 5, at most 10 min).
  - Hold and drag moves a block. While it is dragged, a line in the accent colour marks the gap
    it would land in: before a block when held over its upper half, after it over the lower
    half. No line means the drop would change nothing. A timer can land in any gap: between
    session blocks (also between two loops, or above or below a loop via its rail or rest row),
    or between a loop's timers, which moves it into that loop. Over "+ Timer in loop" it becomes
    that loop's last timer, which is also the way into an empty loop. A loop never goes into a
    loop: held inside one, it lands before or after that loop.
  - "…" button on the trailing edge of each timer block and at the foot of each loop's rail,
    opening a menu: Move Up, Move Down (both within the block's level); for a session timer
    directly below or above a loop "Move into Loop Above" (as its last timer) / "Move into Loop
    Below" (as its first); for a loop's timer "Move out of Loop" (the first timer lands above
    the loop, any other below it); Delete (no confirmation). There is no long-press menu,
    because it would take the long press from the drag.
- Below the blocks: "+ Timer" (opens the Step Editor), "+ Preset" (sheet "Add from Preset" listing
  the timer presets; tapping one adds a copy; without presets: "No Timers" — "Create timer presets
  on the Timers tab"), "+ Loop" (adds an empty 2× loop).
- A failed save keeps the sheet open and marks each problem in place: under the name "Give the
  session a name." or "Another session already has this name." (names compare trimmed and without
  regard to case); below the blocks "Add at least one timer."; inside an empty loop "This loop
  needs at least one timer."

### Step Editor (Sheet)

- The [Preset Editor](#preset-editor-sheet) form (kind, exercise, wheels) applied to one timer of
  a session. Titles "New Timer" / "Edit Timer"; Cancel (xmark) / Done (checkmark) returns to the
  Session Editor, where Save stores everything.

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

- WorkoutRow (card style): exercise name, kind pill, "date · N min · N reps/rounds"; For Time
  shows the finish time as M:SS instead of "N min".
- Tap row → [Workout Log Editor](#workout-log-editor). Edit button → swipe-to-delete (no confirmation).
- All Workouts empty: "No Workouts" — "Complete a workout to see it here".

### Workout Log Editor

- Sheet with a Form: read-only Date, Time, Exercise, Duration (M:SS for For Time), Type (grayed);
  wheel for Reps (1–999; EMOM, For Time) or Rounds (1–99). Toolbar Cancel (xmark) / Save (checkmark).

### Settings

- **Audio:** "Sound" toggle; "Cheer on Completion" toggle (only while Sound is on).
- **Visuals** (toggle cards): Launch Animation, Confetti, Smooth Animations, Show Reps in Center.
- **Manage Your Data:** Clear Workout History / Clear Timer Presets / Clear Sessions / Clear All Data, each with a
  count, disabled when empty, confirmation alert ("… This action cannot be undone."); save failure
  alert "Failed to save changes. Please try again." "Clear Sessions" also clears the week plan.
- **About:** version (build), GitHub link, Privacy Policy link, Acknowledgments sheet.

## Watch App

- **Preset list:** sorted like the iPhone. Leading swipe → Edit; trailing swipe (full swipe allowed)
  → Delete without confirmation; "+" at the bottom; empty state "No presets" — "Create one to get
  started". Tapping a preset starts it.
- **Preset editor (sheet):** "Timer Type" buttons EMOM/AMRAP/For Time; Digital Crown steppers
  (with haptic detents) for duration 1–60 min (not for For Time) and reps (For Time: 1–999); interval text; "Exercise" row → flat list with
  name, muscle group and a checkmark. For Time is dimmed while the exercise is a hold, and holds
  aren't listed for For Time.
- **Workout:** silent countdown with "Get ready" (tap hides it). Paged layout: controls page (End,
  Pause/Resume; resuming jumps back) to the left of the metrics page: TOTAL, INTERVAL (orange in
  the last 3 s) and REPS for EMOM / ROUNDS for AMRAP (tap to count), live heart rate and ACTIVE KCAL.
  For Time: ELAPSED counting up (FINISH once done) and target REPS; tap the metrics page to
  declare done. Pause and
  End stay on the controls page.
  "DONE" at the end until End is pressed. No sounds, no haptics, no confetti, no summary.
- **iPhone-started:** "Starting…" until ownership is settled.
