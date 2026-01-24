# Kraftli Timers
![Platform](https://img.shields.io/badge/platform-iOS%20|%20watchOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![TestFlight](https://img.shields.io/badge/TestFlight-Available-blue)
![Build](https://img.shields.io/github/actions/workflow/status/wuersch/kraftli-timers/ios-build.yml?branch=main&label=build)
![Release](https://img.shields.io/github/v/release/wuersch/kraftli-timers?include_prereleases=true)
![Last Commit](https://img.shields.io/github/last-commit/wuersch/kraftli-timers)
![Issues](https://img.shields.io/github/issues/wuersch/kraftli-timers)
![LOC](https://sloc.xyz/github/wuersch/kraftli-timers?category=code)
![LOC](https://sloc.xyz/github/wuersch/kraftli-timers?category=cocomo)
![LOC](https://sloc.xyz/github/wuersch/kraftli-timers?category=effort)

A native iOS and watchOS app for high-intensity interval training. Minimalistic, distraction-free workout timers for focused fitness sessions.

## Features

### iPhone
- **EMOM Timer** - Interval-based workouts with automatic rep pacing
- **AMRAP Timer** - Time-based rounds, track as many rounds as possible
- **Preset Management** - Save, edit, delete, and reorder timer configurations
- **Workout Stats** - Dashboard with charts, muscle group breakdown, and history
- **Exercise Library** - 21 curated bodyweight exercises with form tips
- **Audio Feedback** - Warning beeps, interval sounds, and completion cheer
- **Settings** - Audio preferences, confetti toggle, animated launch screen

### Apple Watch
- **Standalone Timers** - Run EMOM and AMRAP workouts directly on Watch
- **Preset Editor** - Create and edit presets with Digital Crown input
- **CloudKit Sync** - Presets sync automatically between iPhone and Watch
- **Haptic Feedback** - Wrist taps for interval transitions and warnings
- **Auto-Launch** - Timer appears on Watch when started from iPhone

## Requirements

- iOS 26+ / watchOS 26+
- Xcode 17+
- Swift 6.2

## Getting Started

1. Clone the repository
2. Open `Kraftli Timers.xcodeproj` in Xcode
3. Build and run on simulator or device

## Documentation

- [Features](docs/features.md) - Detailed feature documentation
- [Architecture](docs/architecture.md) - Data models, patterns, and components
- [UI Specification](docs/ui.md) - Interface design and components
- [Future Plans](docs/future.md) - Roadmap and v2+ considerations

## Project Structure

```
Kraftli Timers/
├── App/                          # Entry point and root navigation
├── Features/                     # Feature modules (Timer/, Presets/, Stats/)
├── Models/                       # SwiftData persistence models
├── Services/                     # Protocols + implementations
├── Components/                   # Reusable UI components
├── Modifiers/                    # SwiftUI view modifiers
├── Extensions/                   # Type extensions
└── Audio/                        # Sound files

Kraftli Timers Watch App/
├── App/                          # Watch app entry point
├── Features/                     # Timer and preset modules
├── Services/                     # Watch-specific services
├── Components/                   # Watch UI components
└── Modifiers/                    # Watch view modifiers
```

## Contributing

This is a learning project where educational value matters as much as working code. When contributing:

1. Read through the [documentation](docs/) to understand patterns and conventions
2. Follow existing code style and SwiftUI idioms
3. Keep UI minimalistic - native components, no unnecessary features
4. Test on iOS Simulator (iPhone 17 Pro recommended)

## License

MIT License - see LICENSE file.

## Credits

See ACKNOWLEDGEMENTS file.
