# ADR-0009: Ship the exercise library as bundled, read-only reference data

- **Status:** implemented
- **Date:** 2026-02-02 (recorded retroactively 2026-10-31)
- **Deciders:** Michael Würsch

## Context and Problem Statement

The app ships a curated library of bodyweight exercises (`Exercises.json`, 22 entries). Exercises
were first a SwiftData `@Model`, seeded from the JSON on each device and synced through CloudKit
like presets. Exercises were also seeded on the Watch for standalone use (commit `93b398c`). Each
device seeded its own copy, so CloudKit produced duplicate exercises and seeding races, all for
data the athlete can't change.

How should static exercise data be stored and referenced by presets and workout logs?

## Decision Drivers

- Exercise data is static: it changes only with app releases
- No CloudKit duplicates or seeding races
- Presets and logs must keep working when the library changes

## Considered Options

- Exercises as a synced SwiftData model, seeded from bundled JSON
- Exercises as in-memory reference data loaded from bundled JSON

## Decision Outcome

Chosen option: **in-memory reference data loaded from bundled JSON** (commit `f7045a9`), because
data that never changes doesn't need persistence or sync, and that removes the duplicates and races.

- **Loading:** `ExerciseRepository` loads the JSON into `ExerciseInfo` values at startup on both devices.
- **Presets** store an `exerciseId` instead of a relationship. A one-time migration copied existing relationships into it.
- **Workout logs** store the exercise name as a copy, so the history stays readable if the library changes.
- **Legacy model:** the old `Exercise` model stays in the SwiftData schema only so the migration can read old data.

### Consequences

- Good, because there are no exercise duplicates or seeding races, and every device has the same library instantly, offline.
- Good, because a new app version updates the library simply by shipping new JSON.
- Bad, because the athlete can't add or edit exercises. That would need a new decision.
- Bad, because a preset whose exercise ID disappears from the JSON loses its exercise name, and
  its workouts are logged as "Unknown" (UC-0006, UC-0005).
- Bad, because stats match logs to muscle groups by name, so renaming an exercise detaches its
  older logs from their muscle group (UC-0008).
- Bad, because a failure to load the library degrades silently to an empty list, and duplicate IDs in the JSON crash at startup.
- Neutral: the legacy `Exercise` entity remains in the CloudKit schema until a cleanup migration removes it.

## Pros and Cons of the Options

### Synced SwiftData model, seeded from JSON

- Good, because it is consistent with the other models and could allow user-created exercises later.
- Bad, because per-device seeding creates CloudKit duplicates and seeding races for static data.

### In-memory reference data from bundled JSON

- Good, because it is simple, needs no sync, and the library is identical everywhere.
- Bad, because it is read-only, and references can break when the library changes between releases.

## More Information

- Related: [ADR-0008](ADR-0008-swiftdata-cloudkit-persistence.md).
- Requirements: [UC-0007](../use-cases/UC-0007-choose-an-exercise.md).
