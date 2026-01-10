# Kraftli Timers – Claude Instructions

Native iOS fitness app for high-intensity, minimalistic workouts.

## Tech Stack
- iOS 26+ | Swift 6.2 | SwiftUI | SwiftData

## Project Goal
Learning project: educational value matters as much as working code. Explain SwiftUI concepts when introducing new patterns.

## Features v1
- **EMOM Timer**: Interval-based workouts (customizable interval = duration / reps)
- **AMRAP Timer**: Time-based rounds, track rounds completed
- **Preset Management**: Save and reuse timer configurations
- **UI**: Minimalistic, native components, no Liquid Glass effects

## Domain Model
- `TimerPreset`: id, kind, duration, exercise, reps (optional for EMOM)
- `TimerKind`: Enum - EMOM | AMRAP
- `Exercise`: Name (e.g., 6 Count Burpees, Navy Seals, High Jumps)

## Project Structure
- `App/` - Entry point and root navigation
- `Features/` - Feature modules with co-located Model+View (e.g., `Timer/EMOM/`)
- `Models/` - SwiftData persistence models only (not runtime state)
- `Services/` - Protocols + implementations (dependency injection pattern)
- `Components/` - Reusable UI components
- `Modifiers/` - SwiftUI view modifiers
- `Extensions/` - Type extensions
- `Audio/` - Sound files

## Design Philosophy
- Use native SwiftUI components (Button, List, NavigationStack)
- Adopt iOS 26 design elements where they enhance minimalism (pill shapes, rounded corners)
- Avoid glass effects on minimalist UI - clarity over visual effects
- Dark background + minimal UI = keep it simple

## Workflow
1. Plan before coding: summarize approach, list assumptions and options
2. Ask questions if requirements unclear
3. Discuss new feature ideas before adding them to SPEC.md - don't assume
4. Update SPEC.md once planning is complete and approved
5. Implement in small, testable steps
6. Branch for each feature: `feature/name` or `fix/name`
7. Present options with tradeoffs when multiple approaches exist

## Commands
- Build: `xcodebuild -scheme "Kraftli Timers" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
- Run tests: `swift test`
- Run in simulator: Xcode

## Documentation
- Keep SPEC.md updated with all features
- Before implementing new features: update SPEC.md in Plan Mode
- Status indicators: ✅ Implemented | 🚧 In Progress | 📋 Planned
