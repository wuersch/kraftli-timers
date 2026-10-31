# Kraftli Timers - Backlog

Future features and ideas. Items here are **not in active scope**.

> **Promotion Rule**: Backlog items require explicit discussion and approval before implementation. Promoting an item means specifying it as a use case (`/adlc:use-case`) in [use-cases/](use-cases/). Do not implement directly from this file.

---

## Form Tips During Workout

**Priority**: Low (nice-to-have)

Display form tips overlay when timer is paused. Uses the `formTips` already bundled with each exercise ([ADR-0009](adr/ADR-0009-bundled-exercise-library.md)).

---

## Programs

**Priority**: Medium

Combine timer presets into structured training programs with scheduling and progression.

### Use Cases
- Simple rotation: 4x/week, alternate between exercises
- Weekly progression: Month-long program with increasing difficulty
- Mixed workouts: Combine EMOM and AMRAP in a single session

### Functionality
- Create programs from existing presets
- Define schedule (times per week, specific days)
- Organize into phases with progression
- Track active program and next workout
- Visual progress: "Step 1/4", "Week 3/8"

### Data Model (Draft)
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

---

## Workout Stats Enhancements

**Priority**: Low (after Programs)

### Personal Bests
- Track best performance per exercise
- Handle complexity: same reps in different durations
- Requires more data and pattern understanding

### Trend Analysis
- Trend arrows (up/down) like Apple Health
- Requires 6+ months of historical data
- 90-day vs 365-day comparison

### Program Integration
- Link workouts to program phases
- Progress visualization (timeline, milestones)
- `programId` field in WorkoutLog (reserved)

---

## AI-Assisted Program Generation

**Priority**: Low

Generate personalized training programs based on fitness level and goals.

### Functionality
- Short conversational flow:
  - Current fitness level
  - Training goals
  - Available days per week
  - Session duration preference
- On-device AI generates personalized program
- User can review, tweak, and save

### Technical Approach
- Apple Foundation Models (iOS 26+) - free, on-device, private
- `@Generable` macro for structured output
- `@Guide` constraints to use only curated exercises

### Dependencies
Requires Exercise Library and Programs features.

---

## HealthKit Enhancements

**Priority**: Medium

Recording workouts to Apple Health, live heart rate on the Watch and the post-workout summary are
implemented ([UC-0005](use-cases/UC-0005-record-a-workout.md), [ADR-0002](adr/ADR-0002-healthkit-integration.md)). Remaining ideas:
- Heart rate for iPhone-owned workouts via an iOS 26 `HKWorkoutSession` on iPhone (AirPods / BLE straps)
- Programs integration (single session spanning multiple exercises)

---

## Settings Enhancements

**Priority**: Low to Medium

Deferred settings features for future consideration:

### Appearance / Themes
- Color scheme customization (EMOM/AMRAP ring colors, muscle group colors)
- Requires Asset Catalog color sets and theme system
- Complexity: High (affects many views)

### Data Export
- Export workout history to CSV/JSON
- Use iOS Share Sheet for destination flexibility (Files, Mail, AirDrop)
- Consider privacy implications

### iCloud Sync Toggle
- Enable/disable sync across devices
- Dependent on iCloud sync feature implementation
- Use NSUbiquitousKeyValueStore for settings sync

### Haptic Feedback Toggle
- Enable/disable haptic feedback on button presses and interval changes

### Sound Selection
- Choose interval beep sound from multiple options
- Options could include:
  - **Subtle** - softer tone for quiet environments (early morning, sleeping kids)
  - **Clear** - piercing 880Hz beep for noisy gyms
  - **System** - original system sound (quieter, uses ringer volume)
- Preview sounds before selecting
- Balances "audible in loud environments" vs "non-intrusive at home"

---

## Follow a Watch-Started Workout on iPhone

**Priority**: Low

A workout started on the Watch isn't shown on the iPhone today ([UC-0004](use-cases/UC-0004-run-a-workout-on-apple-watch.md)).
Under the single-owner model this becomes a pure viewer feature: the iPhone renders the Watch's
snapshots ([ADR-0006](adr/ADR-0006-single-owner-timer-state.md)).

---

## Other Ideas

- Rest periods between intervals
- Tabata timer mode
- Simple timer mode
- Adaptive presets (automatic progression based on feedback)
