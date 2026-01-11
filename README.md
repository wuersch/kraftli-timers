# Kraftli Timers

A native iOS app for high-intensity interval training. Minimalistic, distraction-free workout timers for focused fitness sessions.

## Features

- **EMOM Timer** - Interval-based workouts with automatic rep pacing
- **AMRAP Timer** - Time-based rounds, track as many rounds as possible
- **Preset Management** - Save and reuse timer configurations
- **Workout Stats** - Track completed workouts and view progress over time
- **Exercise Library** - 21 curated bodyweight exercises with form tips

## Requirements

- iOS 26+
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
├── App/              # Entry point and root navigation
├── Features/         # Feature modules (Timer/, Presets/, Stats/)
├── Models/           # SwiftData persistence models
├── Services/         # Protocols + implementations
├── Components/       # Reusable UI components
├── Modifiers/        # SwiftUI view modifiers
├── Extensions/       # Type extensions
└── Audio/            # Sound files
```

## Contributing

This is a learning project where educational value matters as much as working code. When contributing:

1. Read through the [documentation](docs/) to understand patterns and conventions
2. Follow existing code style and SwiftUI idioms
3. Keep UI minimalistic - native components, no unnecessary features
4. Test on iOS Simulator (iPhone 17 Pro recommended)

## License

Private project - not for redistribution.

## Credits

- App icon by Guilherme Silva Soares via The Noun Project
