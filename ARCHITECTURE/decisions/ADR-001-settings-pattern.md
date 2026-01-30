# ADR-001: Settings Pattern with @Observable + @AppStorage

**Status**: Accepted
**Date**: 2025-01-01

## Context

The app needs to persist user preferences (audio style, confetti toggle, launch screen toggle) across sessions. These settings should be:
- Persisted to disk automatically
- Reactive (UI updates when settings change)
- Accessible from multiple views
- Simple to extend with new settings

## Decision

Use an `@Observable` class (`AppSettings`) with `@AppStorage` properties for user preferences. Inject via SwiftUI environment.

```swift
@Observable
final class AppSettings {
    @ObservationIgnored
    @AppStorage("completionSoundStyle") var completionSoundStyle: CompletionSoundStyle = .cheering

    @ObservationIgnored
    @AppStorage("confettiEnabled") var confettiEnabled: Bool = true

    @ObservationIgnored
    @AppStorage("launchScreenEnabled") var launchScreenEnabled: Bool = true
}
```

Key implementation details:
- `@ObservationIgnored` prevents double-observation (AppStorage already triggers updates)
- Environment injection via `.environment(settings)` in App
- Factory method on `AudioFeedbackProvider` selects provider based on sound style
- Settings passed explicitly to timer views (no global state)

## Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| SettingsService protocol | Testable, dependency injection | Overkill for 2-3 toggles; no business logic to abstract |
| Scattered @AppStorage | Simple, no coordination | Hard to maintain; no centralized defaults; duplicated keys |
| SwiftData @Model | Consistent with other models | Overkill for simple key-value preferences; slower |
| UserDefaults directly | Maximum control | No reactivity; manual observation needed |

## Consequences

### Positive
- Simple implementation with minimal boilerplate
- Automatic persistence via UserDefaults
- Reactive updates via @Observable
- Centralized defaults and keys
- Easy to add new settings

### Negative
- Less testable than protocol-based approach
- Settings are effectively global (via environment)
- No validation layer

### Neutral
- Uses SwiftUI's built-in mechanisms
- Requires `@ObservationIgnored` to avoid double-observation

## Future Direction

If settings become more complex (10+ settings, validation logic, cloud sync):

1. **Extract SettingsService protocol** for testability
2. **Add UserDefaultsSettingsService** and **InMemorySettingsService** implementations
3. **Consider NSUbiquitousKeyValueStore** for iCloud sync
4. **Group related settings** into nested types (AudioSettings, VisualSettings, etc.)

For now, the pragmatic approach provides sufficient structure without over-engineering.
