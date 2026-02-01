# Kraftli Timers - Backlog

Future features and ideas. Items here are **not in active scope**.

> **Promotion Rule**: Backlog items require explicit discussion and approval before implementation. Do not implement directly from this file.

---

## Form Tips During Workout

**Priority**: Low (nice-to-have)

Display form tips overlay when timer is paused. Uses existing `formTips` data from Exercise model.

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

## HealthKit Integration

**Priority**: Medium (can be implemented alongside Workout History)

> **Detailed Spec**: See [SPEC/healthkit-workoutkit-integration.md](healthkit-workoutkit-integration.md) for full UX flows, scenarios, and technical implementation plan.

### Phase 1 (Current Focus)
- Record completed workouts to Apple Health (duration, type, calories)
- Capture heart rate during workout via Watch workout session
- Best-effort: works with or without Watch app running
- No live HR display in timer views (data collected in background)

### Future Phases
- Live heart rate display during workouts
- Post-workout summary screen
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

## Watch → iPhone Timer Triggering

**Priority**: Medium (next session after HealthKit integration)

Allow Watch-started timers to also start the iPhone timer (if app is running).

### Current Behavior
- iPhone → Watch: Sends message to start mirrored timer on Watch
- Watch → iPhone: Does not trigger iPhone timer (intentional for watch-only workouts)

### Proposed Change
- Watch sends "start timer" message to iPhone when workout begins
- iPhone starts mirrored timer if app is running and reachable
- Enables: larger display, iPhone-based summary screens, consistent experience

### Consideration
- iPhone app might not be running — fail silently, Watch continues independently
- Maintains watch-only workout support (phone at home scenario)

---

## Other Ideas

- Rest periods between intervals
- Tabata timer mode
- Simple timer mode
- Adaptive presets (automatic progression based on feedback)
