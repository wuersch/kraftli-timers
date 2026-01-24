# Kraftli Timers - Specification

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

## Documentation

| Document | Contents |
|----------|----------|
| [Features](docs/features.md) | Detailed feature documentation |
| [Architecture](docs/architecture.md) | Data models, patterns, components |
| [UI](docs/ui.md) | Interface specifications |
| [Future](docs/future.md) | v2+ roadmap and ideas |

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

## Known Issues

### WatchConnectivity Instant Sync Not Wired Up

**Status**: 🐛 Incomplete Implementation

The `WatchConnectivityService.onPresetsReceived` callback is declared but never connected to persist presets on the Watch side. This was intended to provide instant preset sync when the iPhone app backgrounds (via `updateApplicationContext`), supplementing CloudKit.

**Current behavior**: Preset sync relies entirely on CloudKit, which works but may have delays.

**Impact**: Low - CloudKit sync works correctly, this would just make it faster.

**To fix**: Wire up `onPresetsReceived` in the Watch app to persist received presets to SwiftData. Must handle bidirectional sync correctly (Watch can also create presets).

**Files involved**:
- `WatchConnectivityService.swift` - `onPresetsReceived` callback (line ~120)
- `Kraftli_Timers_WatchApp.swift` - Needs to set up the callback handler

---

## Operational Notes

### CloudKit Schema Deployment

When making schema changes (adding fields, record types, etc.):

1. Changes are automatically applied to the **Development** CloudKit environment during Xcode builds
2. **TestFlight and App Store builds use Production** - schema must be manually deployed
3. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/) → Your Container → Schema → **Deploy Schema Changes...**
4. Failure to deploy results in silent sync failures in production builds

---

*See [docs/](docs/) for detailed documentation.*
