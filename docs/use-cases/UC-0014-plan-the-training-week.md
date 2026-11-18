# UC-0014: Plan the training week

- **Status:** approved
- **Primary Actor:** Athlete
- **Goal:** As an athlete with fixed training days, I want to assign a session to each training
  day of my week, so the app knows what I'm training today without me picking it every time.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- At least one session exists ([UC-0013](UC-0013-compose-a-training-session.md)).

## Success Guarantee

- The athlete's week plan is stored: each weekday holds at most one session, or nothing (a rest day).
- The plan repeats every week until the athlete changes it, and is the same on all their devices.

## Trigger

The athlete wants to set up or change their training week.

## Main Success Scenario

1. Athlete asks to see the week plan.
2. System shows the seven weekdays, starting with the first weekday of the athlete's region, each
   with its planned session or as a rest day, and marks today.
3. Athlete assigns a session to a weekday.
4. System stores the assignment and makes it available on the athlete's other devices.
   Steps 3–4 repeat as needed.

## Extensions

- 1a. No session exists yet:
  - 1a1. System says that sessions need to be composed first and offers to compose one
    ([UC-0013](UC-0013-compose-a-training-session.md)).
  - 1a2. Use case ends.
- 3a. Athlete assigns a session to a weekday that already has one:
  - 3a1. The new session replaces the old one on that day.
  - 3a2. Use case continues at step 4.
- 3b. Athlete clears a weekday:
  - 3b1. System makes it a rest day.
  - 3b2. Use case continues at step 4.
- 3c. Athlete assigns the same session to several weekdays:
  - 3c1. System allows it; all of them refer to the same session, so a change to the session
    applies on every one of those days.
  - 3c2. Use case continues at step 4.
- 3d. A planned session is deleted ([UC-0013](UC-0013-compose-a-training-session.md) extension 1b):
  - 3d1. Its weekdays become rest days.
  - 3d2. Use case continues at step 2.

## Special Requirements

- The plan syncs through the athlete's private iCloud database
  ([ADR-0008](../adr/ADR-0008-swiftdata-cloudkit-persistence.md)).
- The plan has no dates: no single-week exceptions, no history of past plans, no tracking of
  missed days.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#training) (a calendar week, no month view).
- Known deviation: not implemented yet.
- [UC-0015](UC-0015-run-a-training-session.md) uses the plan to offer today's session.
- Out of scope (backlog): dated plans, progression over weeks, missed-day tracking.
