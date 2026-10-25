# Plan: Single-owner timer state (ADR-006 / ADR-007)

**Branch**: `feature/watch-owned-timer-state`
**Status**: In progress — steps 1–3 done, step 4 next
**Date**: 2026-10-25

Goal: replace event replication between iPhone and Watch with one owner publishing versioned
`TimerState` snapshots, and optimistic viewer intents. This addresses every finding from the
October 2026 sync review, including "Watch app sometimes doesn't start".

## Review findings → where they're addressed

| # | Finding | Fixed by |
|---|---------|----------|
| 1 | Start offset (wake-up jitter, 400 ms GO delay, Watch skip/late-join lead) | Step 2 — shared `startDate`, implicit countdown |
| 2 | Initiating device pauses/resumes on local clock | Steps 1, 4 — owner applies tap-time intents |
| 3 | Asymmetric HK/WC arbitration drops iPhone pause | Step 7 — arbitration removed |
| 4 | Mirroring handler set in `onAppear` | Step 5 — set in `App.init` |
| 5 | `hasActiveSession` true for ended session | Step 7 — mirrored state no longer drives timer logic |
| 6 | Stale `lastTransitionDate` after reconnect | Step 7 — removed |
| 7 | AMRAP `+1` messages lost/dropped | Steps 1, 4 — absolute `roundCount`, queued intents |
| 8 | `watchHandledWorkout` set on launch request | Step 5 — ownership confirmed by snapshot |
| — | Watch sometimes doesn't start (launch error swallowed; orphan cleanup ends fresh session) | Steps 5, 6 |

## Steps

Each step builds on its own, keeps the app working, and comes with unit tests. Device testing
happens after steps 5, 6 and 8 (see matrix below). I'll ask before running the full test suite.

### 0. Accept the ADRs
- Review ADR-006 and ADR-007, settle the open questions below, flip both to *Accepted*.
- Mark ADR-003/004/005 *Superseded by ADR-006* only when step 7 lands.

### 1. Shared state and reducer (pure Swift, no UI) ✅
- `TimerState`, `TimerConfig`, `TimerIntent`, `DeviceRole`, `Finish` in a shared file next to
  `WatchMessage.swift` (`Kraftli Timers/Services/TimerState.swift`).
- `TimerStateReducer`: `apply(_:to:now:)` implementing ADR-007's table, `completingIfDue(_:now:)`;
  `elapsed(at:)`, `isCountingDown(at:)`, `isFinished(at:)`.
- Added both files to the Watch target's membership exceptions in `project.pbxproj` (the step Xcode would otherwise need manually).
- Tests: elapsed with pauses, countdown boundary, completion clamp, intent batch accept/reject,
  round commutation, stop-when-stale, intent dedup, revision ordering.

### 2. Timer models render from state ✅
- `EMOMTimerModel` / `AMRAPTimerModel` gain `apply(_ state: TimerState)`. The tick computes display
  fields from `reducer.elapsed(at: now())` instead of the private `totalStartDate` /
  `pausedTotalTime`.
- Keep the display math and the feedback trackers. A snapshot that jumps pre-seeds the trackers
  (generalising today's `start(at:)`), so sounds never replay.
- `didComplete` is derived from the state (`finish` or elapsed ≥ total), still set only inside the tick.
- Countdown display (3-2-1-GO) is derived from `startDate − now` on both devices. `CountdownCoordinator`
  and `WatchCountdownCoordinator` shrink to display + beep, no longer driving the start.
- Tests: port the existing model tests to state-driven equivalents; add jump/no-replay tests.
- *Done as:* the models run on an internal `TimerState`; their old `start`/`pause`/`resume(at:)`/`start(at:)`
  methods are thin wrappers over the reducer so the current views keep working. **Deferred to step 7:**
  the countdown coordinators still drive the start, and AMRAP rounds are still counted in the model.

### 3. Transport: `TimerSyncTransport` ✅
- Protocol with `publish(_ state:)`, `send(_ intents:)`, and async streams for incoming
  snapshots and intents.
- Implementations: HK mirrored-session data (`sendToRemoteWorkoutSession` /
  `didReceiveDataFromRemoteWorkoutSession`), WC context + `sendMessage` + `transferUserInfo`, and a
  composite that fans out to all available channels and filters by `workoutID` and `revision`.
- Message coding stays in `WatchMessageCoder` (new message types `timerState`, `timerIntents`,
  `startRequest`).
- Tests with in-memory fake channels: duplicates, reordering, drops, late delivery.
- *Done as:* `TimerSyncPayload` (state or intents, JSON-encoded once) travels under its own
  WatchConnectivity key (`timerSync`), separate from the legacy `WatchMessageCoder` path, which stays
  untouched until step 7. Incoming payloads are delivered through callbacks (`onPayload`,
  `onReconnect`) to match the codebase's existing style, not async streams. The pure
  `TimerSyncInbox` does the filtering (expected workout only, higher revisions only, unseen intents
  only). `WatchConnectivityService` is now symmetric (context, user info and reply-less messages in
  both directions), and `MirroredWorkoutObserver` / `WorkoutSessionManager` forward session data.
- **Watch out in step 5:** the application context is one slot per direction. The legacy
  `StartTimerMessage`/`StopTimerMessage` context and the new snapshots must not both be published
  from the iPhone. The legacy path has to go when the iPhone starts publishing.

### 4. `TimerSessionController` (one per device, @Observable, @MainActor)
- Holds the role (owner/viewer), the confirmed snapshot and the pending intents. It exposes the
  rendered state and `pause()`, `resume()`, `incrementRound()` and `stop()`.
- Owner: applies intents through the reducer, bumps the revision, publishes, republishes on
  reconnect, and drives `HKWorkoutSession.pause()/resume()` from `pausedAt` changes.
- Viewer: predicts optimistically, batches intents while disconnected, and drops/rolls back on newer
  snapshots. Exposes `isAwaitingOwner` for the "disconnected" indicator.
- Tests: full owner+viewer pair over fake channels, including the ADR-007 conflict cases.

### 5. iPhone: start handshake and ownership
- Move `workoutSessionMirroringStartHandler` setup into `Kraftli_TimersApp.init` (finding 4).
- Start flow: decide whether a Watch is available → `StartRequest` + `startWatchApp` → "Starting
  on Watch…" → wait for revision 1 → countdown. On a timeout (5 s) or a thrown error, the iPhone
  becomes owner and shows "Watch not available — running on iPhone".
- Health-save decision = `state.owner == .phone`. Delete `watchHandledWorkout`.
- 🔍 **Device test checkpoint A** (start paths only).

### 6. Watch: owner flow
- `handle(_ workoutConfiguration:)` + `StartRequest` → start the HK session, wait for `.running`,
  start mirroring, publish revision 1 (`startDate = now + 3 s`).
- Yield rule: seeing `owner: .phone` for its `workoutID` → end the session without saving, then
  become viewer (or dismiss — see open question 2).
- Fix the orphan-cleanup race: skip cleanup while a start is pending or a session exists, and
  check again after `await recoverActiveWorkoutSession()` before ending anything.
- Watch-started workouts: Watch is owner from the start, same publishing.
- 🔍 **Device test checkpoint B** (start, pause/resume from both sides, disconnects).

### 7. Wire the views, delete the old paths
- iPhone `EMOMTimerView`/`AMRAPTimerView` and Watch timer views bind to the controller.
- Delete: `TimerControlMessage`, `StopTimerMessage`, `StartTimerMessage.displayOnly`,
  `WatchSyncHandler`, both reconcile functions, the ADR-005 gates, `MirroredWorkoutObserver`'s timer
  role (it keeps only the session handle for the data channel), and most of the coordinator dedup.
- `TimerLifecycleModifier`: background no longer pauses an owned-elsewhere workout. An iPhone-owned
  workout keeps today's behavior.

### 8. Completion and logging
- The owner sets `finish`. The final snapshot and `WorkoutSessionEndedMessage` go out over all
  channels, including `transferUserInfo`.
- The iPhone writes the `WorkoutLog` for iPhone-started workouts from the final state (reps/rounds
  from the state, not from its local model). The Watch writes it for Watch-started ones (unchanged).
- If the owner never reports, the starting device logs from its predicted state at time-out (ADR-007 §4).
- 🔍 **Device test checkpoint C** (full matrix).

### 9. Documentation
- `ARCHITECTURE/architecture.md`: the HealthKit/sync section and the component tables.
- `SPEC/scope.md`: the "iPhone → Watch Timer Sync" and "Synchronized Countdown" sections. Their
  limitations text is already outdated (it says Apple doesn't allow programmatic Watch launch).
  Add the "Starting on Watch…" step.
- ADR-003/004/005 → Superseded. ADR-002: note that the owner, not the start location, saves to Health.
- Bump `MARKETING_VERSION` of the iOS and Watch app targets (Debug + Release) from 1.5.3 to 1.6.0 as the branch's last commit.

## Device test matrix (real iPhone 17 Pro + Watch)

| Scenario | Expected |
|----------|----------|
| iPhone start, Watch app warm | Countdown begins on both after < 1 s, same digit throughout |
| iPhone start, Watch app cold / not running | "Starting on Watch…" then synced countdown |
| iPhone start, Watch locked or off-wrist | iPhone-only after ≤ 5 s with notice; Health save by iPhone |
| iPhone start, Watch starts after the timeout | Watch yields; exactly one Health workout |
| No Watch paired (or Watch app removed) | Immediate iPhone-only start, no wait |
| Pause/resume ×10 alternating devices | Displays never differ by a digit for more than a frame |
| Pause on iPhone with Bluetooth off, resume on iPhone, Bluetooth on | Watch adopts both at tap times |
| Pause on both devices while disconnected | Watch's state wins; iPhone snaps back |
| AMRAP rounds tapped on both devices, incl. while disconnected | Counts converge to the sum |
| Lock iPhone mid-workout 2 min, unlock | iPhone shows the correct time immediately |
| Force-quit iPhone app mid-workout, reopen | Rejoins at the correct time |
| Stop on Watch while disconnected | iPhone ends when the stop arrives; logged as stopped |
| Workout runs to completion | One `WorkoutLog`, one Health workout with HR, summary metrics on iPhone |

## Decisions (2026-10-25)

1. **Handshake timeout**: 5 s. ✅
2. **Late Watch after iPhone takeover**: yields (ends its HK session without saving), then becomes
   a viewer of the iPhone-owned workout. No heart rate is recorded. The existing
   `WKExtendedRuntimeSession` fallback keeps the screen alive. ✅
3. **Snap-back feedback**: when a viewer's pause/resume is rejected and the display jumps to the
   owner's state, show a short neutral hint ("Synced with Watch" / "Synced with iPhone").
   ✅
4. **Scope**: showing Watch-started workouts live on iPhone stays in the backlog. ✅

## Risks

- `sendToRemoteWorkoutSession` is reported to hang for the rest of a workout in ~5% of sessions.
  This is mitigated by publishing on all transports with idempotent apply.
- Mirroring needs the session to be prepared or running first. Publishing over WC until then is
  part of step 6.
- Large refactor of tested code: keep each step mergeable, and run the existing tests (with your
  OK) before deleting old paths in step 7.
