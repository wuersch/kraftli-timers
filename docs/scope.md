# Kraftli Timers – Current Scope (v1.6)

Native iOS + watchOS app for high-intensity interval training: minimalistic, distraction-free
workout timers.

- **Target users:** athletes doing short, intense bodyweight workouts (about 20-minute sessions,
  up to 4× per week)
- **Design principle:** minimal UI with native iOS 26 components; clarity over visual effects

The use cases are the normative requirements. Only use cases with status `approved` or later may
be implemented; ideas live in the [backlog](backlog.md) until promoted to a use case.

## Use Cases

| ID | Goal | Level | Status |
|----|------|-------|--------|
| [UC-0001](use-cases/UC-0001-run-an-emom-workout.md) | Run an EMOM workout | user-goal | approved |
| [UC-0002](use-cases/UC-0002-run-an-amrap-workout.md) | Run an AMRAP workout | user-goal | approved |
| [UC-0003](use-cases/UC-0003-run-an-iphone-started-workout-with-the-watch.md) | Run an iPhone-started workout together with the Watch | user-goal | approved |
| [UC-0004](use-cases/UC-0004-run-a-workout-on-apple-watch.md) | Run a workout on the Apple Watch alone | user-goal | approved |
| [UC-0005](use-cases/UC-0005-record-a-workout.md) | Record a workout | subfunction | approved |
| [UC-0006](use-cases/UC-0006-manage-timer-presets.md) | Manage timer presets | user-goal | approved |
| [UC-0007](use-cases/UC-0007-choose-an-exercise.md) | Choose an exercise for a preset | subfunction | implemented |
| [UC-0008](use-cases/UC-0008-review-workout-stats.md) | Review workout history and stats | user-goal | approved |
| [UC-0009](use-cases/UC-0009-correct-or-delete-a-logged-workout.md) | Correct or delete a logged workout | user-goal | implemented |
| [UC-0010](use-cases/UC-0010-configure-app-preferences.md) | Configure app preferences | user-goal | approved |
| [UC-0011](use-cases/UC-0011-clear-stored-data.md) | Clear stored data | user-goal | implemented |

`approved` means the specified behavior isn't fully realized yet; each such use case lists its
known deviations under *Related Information*. `implemented` means the app behaves as specified.

Interaction design (screens, gestures, copy): [use-cases/ui-spec.md](use-cases/ui-spec.md).

## Architecture

- Overview of models, patterns and components: [architecture.md](architecture.md)
- Decisions: [adr/](adr/)

| ID | Decision | Status |
|----|----------|--------|
| [ADR-0001](adr/ADR-0001-settings-pattern.md) | User preferences in one @Observable object backed by UserDefaults | draft |
| [ADR-0002](adr/ADR-0002-healthkit-integration.md) | Apple Health via HealthKit workout sessions on the Watch | implemented |
| [ADR-0003](adr/ADR-0003-cross-device-timer-anchoring.md) | Anchor pause/resume on HealthKit's transition date | superseded by ADR-0006 |
| [ADR-0004](adr/ADR-0004-application-context-timer-command.md) | Application context as timer-command channel | superseded by ADR-0006 |
| [ADR-0005](adr/ADR-0005-mirrored-control-arbitration.md) | HealthKit as sole pause/resume channel while mirrored | superseded by ADR-0006 |
| [ADR-0006](adr/ADR-0006-single-owner-timer-state.md) | One device owns the timer state, replicated as snapshots | implemented |
| [ADR-0007](adr/ADR-0007-optimistic-viewer-control.md) | Optimistic viewer intents, owner wins | implemented |
| [ADR-0008](adr/ADR-0008-swiftdata-cloudkit-persistence.md) | SwiftData synced as peers via private CloudKit | implemented |
| [ADR-0009](adr/ADR-0009-bundled-exercise-library.md) | Bundled, read-only exercise library | implemented |
