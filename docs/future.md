# Future Considerations

Roadmap and v2+ feature ideas.

## Form Tips During Workout

**Priority**: Low (nice-to-have)

Display form tips overlay when timer is paused. Uses existing `formTips` data from Exercise model.

---

## Programs

**Priority**: 2

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

## watchOS Companion App

**Priority**: 2.5

Run timers from Apple Watch without needing phone nearby.

### Functionality
- List timer presets synced from iPhone
- Default timer for standalone mode (App Store compliance)
- Simplified UI: rings and content only
- Haptic feedback instead of audio
- Run-only (no preset creation on Watch)

### Data Sync
- **Watch Connectivity**: Real-time sync when iPhone nearby
- **CloudKit/iCloud**: Background sync for standalone operation

### Smart Remote Control
- Starting on Watch controls iPhone only if app is active/unlocked
- Independent operation when iPhone unavailable

### Technical Notes
- Reuse timer models (same logic, different UI)
- Use FoundationTimerProvider (no CADisplayLink on watchOS)
- SwiftData works on watchOS 10.4+ with shared CloudKit container

---

## Workout Stats Enhancements

**Priority**: After v1 Stats + Programs

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

**Priority**: 4

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

**Priority**: Can be implemented alongside Workout History

### Write to HealthKit
- Record completed workouts (duration, type, estimated calories)
- Enables rewards in health insurance apps
- Read active calorie data to refine estimates

### Live Heart Rate Display (requires Apple Watch)
- Show real-time heart rate on iPhone during workouts
- Small beating heart icon with BPM
- Streams from Watch via HealthKit workout session
- Hidden if no Watch or heart rate unavailable

### Post-Workout Summary Screen
- Appears after timer completes
- Stats: Duration, Reps/Rounds, Heart rate (min/avg/max), Calories
- Provides tangible feedback

### Programs Integration
- Single HealthKit session spans entire program
- Summary only after final exercise
- Standalone timers show summary immediately

---

## Settings Enhancements

**Priority**: Low to Medium

Deferred settings features for future consideration:

### Appearance / Themes
- Color scheme customization (EMOM/AMRAP ring colors, muscle group colors)
- Requires Asset Catalog color sets and theme system
- Complexity: High (affects many views)

### EMOM Display Options
- Option to swap reps and countdown prominence
- For users who focus more on rep counting during workouts

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

### Keep Screen Awake
- Already implemented during workouts
- Could add toggle if users want different behavior

---

## Other Ideas

- Rest periods between intervals
- Custom audio cues
- Tabata timer mode
- Simple timer mode
- Adaptive presets (automatic progression based on feedback)

---

## Status Legend

- ✅ **Implemented**: Complete and tested
- 🚧 **In Progress**: Currently being developed
- 📋 **Planned**: Documented but not started
- 🔮 **Future**: Under consideration for later versions
