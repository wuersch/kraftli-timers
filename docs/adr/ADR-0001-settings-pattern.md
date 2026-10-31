# ADR-0001: Hold user preferences in one @Observable AppSettings object backed by UserDefaults

- **Status:** draft
- **Date:** 2025-01-01 (amended 2026-10-31)
- **Deciders:** Michael Würsch

## Context and Problem Statement

The app persists a handful of user preferences across launches (sound, completion sound style,
confetti, launch animation, smooth animations, reps-in-center). They must be persisted
automatically, update the UI when they change, be reachable from many views, and be simple to
extend.

How should the app store and expose user preferences?

## Decision Drivers

- Persistence without boilerplate
- SwiftUI reactivity
- One place for keys and defaults
- Proportionate to a few toggles with no business logic

## Considered Options

- `@Observable` `AppSettings` class persisted to UserDefaults, injected via the environment
- `SettingsService` protocol with injectable implementations
- Scattered `@AppStorage` properties in individual views
- SwiftData `@Model`
- UserDefaults read directly from views

## Decision Outcome

Chosen option: **an `@Observable` `AppSettings` class persisted to UserDefaults**, injected with
`.environment(settings)`. It gives reactivity and central defaults with minimal code, and stays
proportionate to a few toggles.

- Initially (2025-01-01) the properties were `@AppStorage` wrappers marked `@ObservationIgnored`,
  so they wouldn't be observed twice.
- **Amendment (2026-10-31, documenting v1.2.0, commit `b670e0a`):** the properties are plain
  stored properties. A `didSet` writes each value to `UserDefaults.standard`, `init` loads it with a
  default, and a private `Key` enum holds the key names.
  [NEEDS CLARIFICATION: Why was `@AppStorage` replaced by manual UserDefaults persistence in
  v1.2.0? The commit gives no reason.]
- The timer screen picks the feedback provider from the settings (silent when sound is off,
  otherwise cheering or neutral), and settings are passed explicitly to timer views.

### Consequences

- Good, because the implementation is small, persistence is automatic, and UI updates come from `@Observable`.
- Good, because keys and defaults live in one place, and adding a setting is one property.
- Bad, because the type is concrete (no protocol), so tests and previews share `UserDefaults.standard`.
- Bad, because settings are effectively global through the environment and have no validation layer.
- Bad, because settings are local to each device and don't sync through iCloud (see
  [ADR-0008](ADR-0008-swiftdata-cloudkit-persistence.md)).

## Pros and Cons of the Options

### `@Observable` AppSettings + UserDefaults

- Good, because it is simple, reactive, and keeps defaults in one place.
- Bad, because it is less testable than a protocol-based service.

### `SettingsService` protocol

- Good, because it is testable and supports dependency injection.
- Bad, because it is overkill for a few toggles with no business logic.

### Scattered `@AppStorage`

- Good, because it is the simplest option, with no coordination.
- Bad, because keys are duplicated, there are no central defaults, and it is hard to maintain.

### SwiftData `@Model`

- Good, because it would be consistent with the other models.
- Bad, because it is overkill and slower for key-value preferences, and it would sync unintentionally.

### UserDefaults read directly from views

- Good, because it gives the most control.
- Bad, because it has no reactivity, so observation would have to be manual everywhere.

## More Information

Possible future direction, if settings grow (10+ settings, validation, sync):
- Extract a `SettingsService` protocol with UserDefaults and in-memory implementations.
- Consider `NSUbiquitousKeyValueStore` for iCloud sync.
- Group settings into nested types.
