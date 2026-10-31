# ADR-0008: Persist presets and workout history in SwiftData, synced as peers through a private CloudKit database

- **Status:** implemented
- **Date:** 2026-01-18 (recorded retroactively 2026-10-31)
- **Deciders:** Michael Würsch

## Context and Problem Statement

Presets and the workout history must survive app updates, and must appear on the athlete's iPhone and Apple Watch alike. The Watch has to be able to work standalone: create presets and log workouts without the iPhone nearby. The first Watch release (commit `10ba134`) synced presets two ways at once, through CloudKit and through WatchConnectivity. The WatchConnectivity sync treated the iPhone as the source of truth and deleted presets created on the Watch (commit `53d6038`).

How should persistent user data be stored and kept consistent across the athlete's devices?

## Decision Drivers

- The Watch works standalone; neither device is the master
- No custom sync protocol to maintain
- Data stays private to the athlete; no own backend
- SwiftData is the app's persistence framework (project tech stack)

## Considered Options

- WatchConnectivity preset sync with the iPhone as source of truth (alongside CloudKit)
- SwiftData + CloudKit private database only, devices as equal peers

## Decision Outcome

Chosen option: **SwiftData + CloudKit private database only, devices as equal peers**. Both devices write. The system does the syncing, and the WatchConnectivity sync that conflicted with it is gone (`53d6038`).

- **One shared container.** Both targets open the same SwiftData container. It holds `TimerPreset` and `WorkoutLog`, plus the legacy `Exercise` model kept for migration only (see ADR-0009). The container syncs to the private CloudKit database `iCloud.ch.omnom.kraftli.timers`.
- **CloudKit-compatible models** (`7e01f07`). Every attribute has a default or is optional, and every relationship has an inverse.
- **No seed data** (`e44c1bb`). Default presets were created per device behind a UserDefaults flag. CloudKit syncs presets, but UserDefaults doesn't sync, so a second device re-seeded the presets and they merged into duplicates. New installs now start empty.
- **Duplicate cleanup on the iPhone only.** CloudKit merges can still produce identical presets. `PresetMaintenance` runs once after the UI is up. It keeps one preset per (kind, duration, reps, exercise) and deletes the rest, on the iPhone only. The Watch defers to it: if both devices deleted on their own, they could pick different survivors and delete both copies (issue #43). The cleanup never runs inside `App.init`, because holding the SQLite lock while suspended mid-launch causes `0xdead10cc` kills.
- **Settings stay out.** User preferences are per device in UserDefaults (ADR-0001).
- **WatchConnectivity carries no persistent data.** It is kept for live workout traffic only (ADR-0006).

### Consequences

- Good, because both devices are equal peers, and Watch-created presets and Watch-logged workouts reach the iPhone without custom sync code.
- Good, because the data lives in the athlete's own iCloud. There is no backend to run, and a reinstall restores it.
- Bad, because sync timing is up to the system and not observable. A change may take a while to appear on the other device.
- Bad, because CloudKit merges can create duplicate presets. The rule "identical presets are merged" is the price, and it is visible to the athlete (UC-0006).
- Bad, because default presets are no longer possible without a sync-safe design.
- Bad, because schema changes must stay CloudKit-compatible (additive, defaults or optional) and need a CloudKit schema deployment before release.
- Bad, because the app terminates deliberately if the container can't be created. There is no degraded mode.
- Neutral: unit tests use in-memory containers with CloudKit disabled (`8b86790`).

## Pros and Cons of the Options

### WatchConnectivity preset sync, iPhone as source of truth

- Good, because changes reach the other device almost instantly while both are in range.
- Bad, because it competes with CloudKit and deleted Watch-created presets, which breaks standalone Watch use.
- Bad, because it is a custom sync protocol to maintain, and it needs both devices in range.

### SwiftData + CloudKit private database only

- Good, because both devices are equal peers and the platform does the syncing.
- Bad, because propagation delay is opaque, merges create duplicates, and the schema has constraints.

## More Information

- Related: [ADR-0001](ADR-0001-settings-pattern.md) (local settings), [ADR-0009](ADR-0009-bundled-exercise-library.md) (exercises not synced), [ADR-0006](ADR-0006-single-owner-timer-state.md) (live workout traffic).
- Requirements: [UC-0006](../use-cases/UC-0006-manage-timer-presets.md), [UC-0005](../use-cases/UC-0005-record-a-workout.md), [UC-0011](../use-cases/UC-0011-clear-stored-data.md).
