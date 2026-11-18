# ADR-0011: Store a session's elements as one versioned document and the week plan as one record

- **Status:** implemented
- **Date:** 2026-11-18
- **Deciders:** Michael Würsch

## Context and Problem Statement

Training sessions ([UC-0013](../use-cases/UC-0013-compose-a-training-session.md)) are the first
persisted data with structure: an ordered sequence of steps and loops, where a loop holds an ordered
sequence of steps. The week plan ([UC-0014](../use-cases/UC-0014-plan-the-training-week.md)) assigns
at most one session to each weekday. Both must sync through the private CloudKit database
([ADR-0008](ADR-0008-swiftdata-cloudkit-persistence.md)), which allows neither unique constraints
nor required relationships, and whose schema can only grow.

How are a session's elements and the week plan stored so that they stay consistent across the
athlete's devices?

## Decision Drivers

- A session is always edited and saved as a whole, from a draft in the editor.
- Sessions and the plan are edited on the iPhone only; the Watch has no editor for them.
- CloudKit has no ordered relationships. Order and nesting would need sort fields on every level.
- Saving a relationship graph in the test host crashed before (see `PresetMaintenanceTests`).
  The existing models reference each other by UUID for that reason.
- The session runner ([UC-0015](../use-cases/UC-0015-run-a-training-session.md)) needs the
  elements as one ordered value.
- A CloudKit schema can't be changed once deployed, only extended.

## Considered Options

For a session's elements:

- Related SwiftData models (session → element → step)
- A Codable composite attribute holding the elements
- A versioned JSON document in a `Data` attribute

For the week plan:

- One record with seven optional session ids
- One row per weekday with a modification date, and a resolver that picks the newest
- The weekdays as a field on the session

## Decision Outcome

Chosen options: **a versioned JSON document in a `Data` attribute** and **one record with seven
optional session ids**, because a session is one unit of editing and the plan has a single editor,
so neither needs to merge partial changes.

- **`TrainingSession`** holds `id`, `name` and `elementsData`. The data is a `SessionDocument`:
  a format version and the elements (`SessionStep`, `SessionLoop`) as plain Codable values. A loop
  holds steps only, so the type itself rules out a loop inside a loop.
- **Reading is tolerant.** Unknown fields are ignored and later additions are optional, so an
  older app version can still read a newer document. Data that can't be read at all counts as a
  session without elements; nothing crashes.
- **`WeekPlan`** holds one optional session id per weekday. It refers to sessions by UUID, with no
  relationship, like a preset refers to its exercise.
- **A session id that doesn't resolve counts as a rest day.** Deleting a session also clears its
  days, but the plan never relies on that having happened on another device.
- **If sync produces several plan records, the one with the lowest id is used.** None is deleted.
- **Two sessions with the same name are both kept.** The editor asks for a unique name on save;
  sync is never corrected by deleting or renaming.

### Consequences

- Good, because a session is stored and synced atomically: never half of one device's edit.
- Good, because order and nesting are simply the order in the document; there are no sort fields
  and no cascade rules.
- Good, because the models have no relationships, so store-backed tests are safe.
- Good, because the runner gets the elements as the value it needs.
- Bad, because two devices editing the same session lose one of the edits entirely. Accepted:
  only the iPhone edits sessions.
- Bad, because nothing inside a session can be queried, for example "all sessions with burpees".
- Bad, because the document format is ours to migrate. CloudKit and SwiftData don't see inside it,
  so every later change must keep version 1 readable.
- Bad, because a second device that creates a plan while offline loses its plan to the lower id.
- Bad, because the two new record types need a CloudKit schema deployment before release, and
  can't be renamed or removed afterwards.

### Confirmation

`SessionDocumentTests` cover the round trip, unreadable data and unknown fields. The plan's
handling of unresolved ids and of several plan records is covered by tests of its pure functions.

## Pros and Cons of the Options

### Related SwiftData models for the elements

- Good, because single steps could be queried and synced on their own.
- Bad, because every level needs a sort field, and CloudKit can interleave two devices' edits
  into an order nobody chose.
- Bad, because relationships must be optional with an inverse, and deleting needs cascade rules
  the codebase doesn't use anywhere yet.
- Bad, because saving a relationship graph crashed the test host.

### A Codable composite attribute

- Good, because SwiftData does the encoding.
- Bad, because the stored shape follows the Swift types, with nested enums and arrays, and can't
  carry a format version of our own.

### A versioned JSON document in a `Data` attribute

- Good, because the format is explicit, versioned and testable without a store.
- Bad, because the content is opaque to the database.

### One plan record with seven optional session ids

- Good, because "at most one session per weekday" holds by construction.
- Good, because it is the least code: no resolver beyond choosing the record.
- Bad, because it is one record, so two devices changing different days can overwrite each other.

### One row per weekday with a modification date

- Good, because changes to different days merge, and duplicates resolve per day.
- Bad, because sync can create several rows for one day, which needs a resolver and tombstones for
  cleared days. That protects a case that needs a second iPhone editing offline.

### The weekdays as a field on the session

- Good, because no second model is needed.
- Bad, because two sessions can claim the same weekday, and nothing can prevent it.

## More Information

- Builds on [ADR-0008](ADR-0008-swiftdata-cloudkit-persistence.md) (sync constraints) and
  [ADR-0009](ADR-0009-bundled-exercise-library.md) (references by id).
- Clearing sessions and the plan: [UC-0011](../use-cases/UC-0011-clear-stored-data.md).
