# UC-0013: Compose a training session

- **Status:** implemented
- **Primary Actor:** Athlete
- **Goal:** As an athlete, I want to put together named training sessions from timers and repeated
  blocks, such as a warm-up followed by a main part, so I can run a whole training as one workout
  and reuse it on several days.
- **Scope:** Kraftli Timers (iPhone app)
- **Level:** user-goal

## Preconditions

- None. The athlete may have no sessions yet.

## Success Guarantee

- The athlete's sessions are stored, each with a name and an ordered sequence of at least one
  element. An element is either:
  - a **step**: one timer as in a preset, with its kind (EMOM, AMRAP or For Time), its exercise and
    its settings ([UC-0006](UC-0006-manage-timer-presets.md)), or
  - a **loop**: a sequence of at least one step, repeated 2–20 times, with an optional rest of
    whole seconds, at most 10 minutes, after each round except the last.
- The athlete can see roughly how long each session takes. This estimated length is always
  presented as approximate and never changes how a step runs. It adds up, with a loop's steps
  counted once per round:
  - the duration of every EMOM and AMRAP step,
  - the rests of every loop,
  - for every For Time step, an estimate from its target reps and the typical pace of its
    exercise. The estimate grows slightly faster than the number of reps, because the athlete
    tires.
- The sessions are available on all the athlete's devices.

## Trigger

The athlete wants to create, change or remove a session.

## Main Success Scenario

1. Athlete asks to create a new session.
2. System asks for a name that no other session of the athlete has.
3. Athlete adds a step, choosing its kind, exercise ([UC-0007](UC-0007-choose-an-exercise.md)) and
   settings under the same rules as a preset ([UC-0006](UC-0006-manage-timer-presets.md) steps 2–4).
4. System appends the step to the session and shows the session's estimated length.
   Steps 3–4 repeat until the session holds what the athlete wants.
5. Athlete saves the session.
6. System stores it and makes it available on the athlete's other devices.

## Extensions

- 1a. Athlete changes an existing session:
  - 1a1. System presents the session's name and elements.
  - 1a2. Use case continues at step 3.
- 1b. Athlete deletes a session:
  - 1b1. System removes it on all devices. Weekdays it was planned on become free
    ([UC-0014](UC-0014-plan-the-training-week.md)); workouts already recorded from it stay in the
    history.
  - 1b2. Use case ends.
- 1c. Athlete duplicates a session:
  - 1c1. System creates a copy under a new, unique name and presents it for changes.
  - 1c2. Use case continues at step 3.
- 3a. Athlete adds a loop instead of a single step:
  - 3a1. Athlete sets the number of rounds (2–20) and optionally the rest after each round
    (at most 10 minutes).
  - 3a2. Athlete adds one or more steps to the loop, as in step 3. A loop can't contain another loop.
  - 3a3. Use case continues at step 4.
- 3b. Athlete builds a step from an existing preset:
  - 3b1. System copies the preset's kind, exercise and settings into the step. Later changes to the
    preset don't change the step, and vice versa.
  - 3b2. Use case continues at step 4.
- 3c. Athlete reorders, changes or removes an element, or a step within a loop:
  - 3c1. System applies the change to the session being edited.
  - 3c2. Use case continues at step 4.
- 3d. Athlete moves a step into a loop, out of a loop, or from one loop to another:
  - 3d1. System places the step where the athlete put it. A loop itself can't be moved into
    another loop. A loop left without steps stays in the session being edited (see 5a).
  - 3d2. Use case continues at step 4.
- 5a. The session has no elements, or a loop has no steps:
  - 5a1. System doesn't save and says what's missing.
  - 5a2. Use case continues at step 3.
- 5b. The session has no name:
  - 5b1. System doesn't save and asks for a name.
  - 5b2. Use case continues at step 2.
- 5c. Another session already has the name:
  - 5c1. System doesn't save and asks for a different name.
  - 5c2. Use case continues at step 2.
- 5d. Athlete abandons the change:
  - 5d1. System keeps the session as it was, or doesn't create it.
  - 5d2. Use case ends.
- 6a. A step's exercise no longer exists in the library:
  - 6a1. The step keeps working; its workouts are recorded with the exercise "Unknown", as for a
    preset ([UC-0006](UC-0006-manage-timer-presets.md) extension 6b).
  - 6a2. Use case ends.

## Special Requirements

- Sessions sync through the athlete's private iCloud database
  ([ADR-0008](../adr/ADR-0008-swiftdata-cloudkit-persistence.md)). They are composed on the iPhone
  only; the Watch has no session editor.

## Related Information

- Interaction design: [ui-spec.md](ui-spec.md#session-editor-sheet): a block editor in the style
  of Nassi-Shneiderman diagrams or Scratch.
- [UC-0014](UC-0014-plan-the-training-week.md) (planning sessions on weekdays),
  [UC-0015](UC-0015-run-a-training-session.md) (running a session)
- Inspiration: named, reusable workouts as in Freeletics.
- Supersedes the "Programs" draft in the [backlog](../backlog.md); progression over weeks and
  AI-generated programs stay there.
