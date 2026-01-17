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

## v1 Remaining Work

- [x] Settings screen implementation

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
3. **Settings** - App configuration (placeholder)

---

*See [docs/](docs/) for detailed documentation.*
