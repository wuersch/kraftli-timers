# Plan: Single-owner timer state (ADR-006 / ADR-007)

**Branch**: `feature/watch-owned-timer-state`
**Status**: In progress — steps 1–4 and slices 5A–5B done; next: 5C (device test checkpoint A, EMOM)
**Date**: 2026-10-25

Goal: replace event replication between iPhone and Watch with one owner publishing versioned
`TimerState` snapshots, and optimistic viewer intents. This addresses every finding from the
October 2026 sync review, including "Watch app sometimes doesn't start".

## Review findings → where they're addressed

| # | Finding | Fixed by |
|---|---------|----------|
| 1 | Start offset (wake-up jitter, 400 ms GO delay, Watch skip/late-join lead) | Step 2 — shared `startDate`, implicit countdown |
| 2 | Initiating device pauses/resumes on local clock | Steps 1, 4 — owner applies tap-time intents |
| 3 | Asymmetric HK/WC arbitration drops iPhone pause | 5A/5B — arbitration replaced; 5E deletes it |
| 4 | Mirroring handler set in `onAppear` | 5A — set in `App.init` |
| 5 | `hasActiveSession` true for ended session | 5A/5B — mirrored state no longer drives timer logic |
| 6 | Stale `lastTransitionDate` after reconnect | 5E — removed |
| 7 | AMRAP `+1` messages lost/dropped | Steps 1, 4 — absolute `roundCount`, queued intents |
| 8 | `watchHandledWorkout` set on launch request | 5A — ownership confirmed by snapshot |
| — | Watch sometimes doesn't start (launch error swallowed; orphan cleanup ends fresh session) | 5A (visible fallback), 5B (cleanup race) |

## Steps

Each step builds on its own and comes with unit tests. Steps 1–4 kept the app's behavior unchanged.
Steps 5–8 were re-sequenced into the vertical slices 5A–5E (see the note there): on the feature
branch, the app works end to end again only after 5B, so nothing is merged before checkpoint A.
Running the full test suite needs the user's OK (CLAUDE.md), unless they said otherwise for the session.

### 0. Accept the ADRs
- Review ADR-006 and ADR-007, settle the open questions below, flip both to *Accepted*.
- Mark ADR-003/004/005 *Superseded by ADR-006* only when slice 5E lands.

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

### 4. `TimerSessionController` (one per device, @Observable, @MainActor) ✅
- Holds the role (owner/viewer), the confirmed snapshot and the pending intents. It exposes the
  rendered state and `pause()`, `resume()`, `incrementRound()` and `stop()`.
- Owner: applies intents through the reducer, bumps the revision, publishes, republishes on
  reconnect, and drives `HKWorkoutSession.pause()/resume()` from `pausedAt` changes.
- Viewer: predicts optimistically, batches intents while disconnected, and drops/rolls back on newer
  snapshots. Exposes `isAwaitingOwner` for the "disconnected" indicator.
- Tests: full owner+viewer pair over fake channels, including the ADR-007 conflict cases.
- *Done as:* the viewer resends its whole pending list on every tap. A rollback is recorded in
  `lastRollbackDate` for the step-7 hint. Pair tests run over a `FakeLink` that models the real
  channels: while disconnected, messages are lost, the context keeps only the latest state, and
  queued transfers are delivered on reconnect. They found a protocol flaw, which is now fixed:
  split deliveries of a queued pause → resume made the viewer's own resume look like a conflict.
  Pause/resume intents are now chained via `previousPauseIntentID` (ADR-007 updated). Driving the
  HK session from `pausedAt` stays on the Watch side (step 6).

### 5. Vertical slices (re-sequenced 2026-10-25)

The original steps 5–8 (iPhone handshake → Watch owner → wire views → completion) can't be tested
one by one. The iPhone's new start request needs the Watch's answer (step 6). The legacy start
message can't run alongside it, because both use the iPhone's single application-context slot. And
nothing becomes visible until the views render from the controller (step 7). The same work is
therefore done as end-to-end slices, EMOM first, so real devices can be tested as early as possible.

#### 5A. iPhone EMOM on the controller ✅
- Move `workoutSessionMirroringStartHandler` setup into `Kraftli_TimersApp.init` (finding 4).
- iPhone start flow: Watch available (`isPaired && isWatchAppInstalled`)? → `StartRequest`
  (workout ID + config; needs a payload case and the WC transport) + `startWatchApp` →
  "Starting on Watch…" → controller as **viewer**, countdown once revision 1 arrives. On a 5 s
  timeout or a thrown `startWatchApp` → controller as **owner** (`owner: .phone`, published as the
  context so a late Watch yields), with the notice "Watch not available — running on iPhone".
  No Watch → owner immediately, no wait.
- `EMOMTimerView` renders from `controller.renderedState` (`timerModel.apply`). Taps go to
  `controller.pause()/resume()/stop()`, and the countdown display is derived from
  `startDate − now`. The iPhone stops publishing the legacy start/stop context.
- Health-save decision = `state.owner == .phone`. `watchHandledWorkout` is no longer used for EMOM.
- Snap-back hint from `lastRollbackDate`; "Watch disconnected" indicator from `hasUnconfirmedChanges`.
- *Done as:* `Kraftli_TimersApp.init` creates the app's one `TimerSessionController` (WC + HK
  transports) and a `PhoneWorkoutStarter` (`Services/PhoneWorkoutStarter.swift`), which runs the
  handshake and injects both into the environment. `StartRequest` (workout ID, config, `requestedAt`)
  is a new `TimerSyncPayload` case. The composite delivers it once through its own `onStartRequest`
  callback, never through `onPayload`. The controller gained `requestStart(_:)`, `workoutID` and
  `isAwaitingOwner`. A takeover is simply `startAsOwner` with the same workout ID. `CountdownCoordinator`
  is unchanged; its completion now only starts the hint timer, because the model already follows the
  state. Notices use the hint line ("Synced with Watch", "Watch not available — running on iPhone").
  Disconnected shows an `applewatch.slash` icon next to the total time. Pulled forward from 5E: a
  backgrounded iPhone pauses only a workout it owns. `FakeLink` moved to `TestSupport/` and models
  the single context slot for snapshots *and* start requests.
- **Watch out in 5B:** (1) A stop sent during "Starting on Watch…" is an intent with `baseRevision 0`
  (`transferUserInfo`). It can reach the Watch before its controller owns the workout, and the inbox
  drops it then. Buffer intents for the requested workout ID until `startAsOwner`, then apply them.
  (2) The start request stays in the iPhone's application context until the next snapshot replaces
  it. Ignore requests whose `requestedAt` is older than the handshake timeout plus a margin, so a
  later cold launch doesn't start a stale workout. (3) With 5A alone, the old Watch code ignores
  the request, so an iPhone EMOM runs iPhone-only after 5 s. This is expected.

#### 5B. Watch as EMOM owner ✅
- `StartRequest` + `handle(_ workoutConfiguration:)` → start the HK session, wait for `.running`,
  start mirroring, `controller.startAsOwner` (`startDate = now + 3 s`). Publish over WC until
  mirroring is up.
- HK `session.pause()/resume()` driven by `renderedState.pausedAt` (owner only). Mirrored HK
  transitions no longer drive timer logic on either device.
- Yield rule: a context with `owner: .phone` for its `workoutID` → end the HK session without
  saving, become viewer, keep the screen alive via `WKExtendedRuntimeSession`.
- Fix the orphan-cleanup race: skip cleanup while a start is pending or a session exists, and
  check again after `await recoverActiveWorkoutSession()` before ending anything.
- `WatchEMOMTimerView` renders from the controller. Watch-started EMOM: Watch is owner from the start.
- *Done as:*
  - **Runtime:** a lazily created `WatchTimerRuntime.shared` (Watch `App/`) owns the
    `WorkoutSessionManager`, the Watch's controller and the `WatchWorkoutStarter`. `App.init` creates
    it before WatchConnectivity activates, and `WorkoutAppDelegate` uses the same instance, so no
    start request is dropped on a cold launch.
  - **Starter:** `WatchWorkoutStarter` lives in the shared `Services/` folder and runs on the Watch.
    HealthKit and the keep-alive are injected, so its tests run in the iOS target over `FakeLink`.
    - A start request makes the Watch a viewer ("Starting…"). The request and
      `handle(_ workoutConfiguration:)` share one session start within 15 s.
    - When the session runs, the Watch calls `startAsOwner`. Mirroring starts without being
      awaited.
    - Requests older than 10 s are ignored.
    - A 10 s watchdog closes the screen if no owner appears.
  - **Yield:** the iPhone outranks the Watch. The inbox accepts an iPhone-owned snapshot over a
    Watch-owned one at any revision and rejects Watch snapshots after that. A Watch owner that
    receives one yields (`TimerSessionController.yield`). The starter then calls the new
    `WorkoutSessionManager.discardSession()` (no Health save) and starts a `WKExtendedRuntimeSession`.
  - **Early intents:** a viewer that waits to own the workout keeps incoming intents and applies
    them right after `startAsOwner`. That is how an iPhone stop sent during "Starting on Watch…"
    takes effect. A workout stopped before its start date discards its session.
  - **HealthKit pause/resume:** still follows the model's `isRunning` via `watchTimerLifecycle`, which
    now comes from the state. On a viewer (no session) these calls are no-ops.
  - **Orphan cleanup:** `recoverActiveSession` checks again after its await and never finalizes a
    session that started meanwhile.
  - **Messages:** the legacy EMOM `StartTimerMessage` is ignored. Completion and logging reuse
    `WatchWorkoutCoordinator.handleWorkoutCompleted`/`stopAndCleanup`, with `displayOnly` meaning
    "iPhone-started", so `WorkoutSessionEndedMessage` still links the Health workout to the
    iPhone's log.
  - **Countdown:** tapping still hides the Watch countdown, but the timer starts at the shared start
    date either way.

#### 5C. 🔍 Device test checkpoint A (EMOM)
- On the real iPhone 17 Pro + Watch: the start-path and pause/resume rows of the matrix below,
  EMOM only.

#### 5D. AMRAP
- The same for `AMRAPTimerView` / `WatchAMRAPTimerView`. Rounds come from
  `renderedState.roundCount`, and taps call `controller.incrementRound()`. The model's own round
  counting goes away (`decrementRoundsCompleted` has no UI callers).

#### 5E. Remove old paths, completion and logging
- Delete: `TimerControlMessage`, `StopTimerMessage`, `StartTimerMessage` (incl. `displayOnly`),
  `WatchSyncHandler`, both reconcile functions, the ADR-005 gates, `MirroredWorkoutObserver`'s timer
  role (it keeps only the session handle for the data channel), `watchHandledWorkout`, the
  models' legacy `start/pause/resume(at:)/start(at:)` wrappers, and most coordinator dedup.
- `TimerLifecycleModifier`: background no longer pauses a workout owned elsewhere. An iPhone-owned
  workout keeps today's behavior.
- Completion: the owner sets `finish`. The final snapshot and `WorkoutSessionEndedMessage` go out over
  all channels, including `transferUserInfo`. The iPhone writes the `WorkoutLog` for
  iPhone-started workouts from the final state; the Watch writes it for Watch-started ones. If the
  owner never reports, the starting device logs from its predicted state when the time runs out
  (ADR-007 §4).
- 🔍 **Device test checkpoint B** (full matrix).

### 6. Documentation
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
- Large refactor of tested code: keep every commit green, and don't merge before checkpoint A.

## Working notes (for a fresh session)

- **Build/test toolchain:** `xcode-select` may still point to the Command Line Tools. Prefix
  `xcodebuild`/`xcrun` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Simulators:** iPhone 17 Pro runs on the iOS 27.0 runtime (27.1 only supports iPhone Duo). For Watch
  tests use `platform=watchOS Simulator,name=Apple Watch Series 12 (46mm)`. Full suites can exceed
  10 minutes: run them in the background.
- **Shared code:** new files in `Kraftli Timers/Services/` that the Watch also needs must be added to
  the "Exceptions for 'Kraftli Timers' folder in 'Kraftli Timers Watch App' target" list in
  `project.pbxproj` (alphabetical).
- **Isolation:** app targets default to MainActor. Types decoded in HealthKit/WC delegate callbacks are
  `nonisolated` (see `TimerState`). Nested helper types in tests need their own `@MainActor`.
  Mutating calls can't go inside `#expect(...)`.
- **SwiftData in tests:** always use `makeInMemoryContainer(for:)` (CloudKit disabled), never a bare
  `ModelConfiguration(isStoredInMemoryOnly:)`.
- **WatchConnectivity:** messages sent with `replyHandler: nil` arrive in `session(_:didReceiveMessage:)`
  without a reply handler. The application context is one slot per direction.
- **Where things are:** state and reducer `Services/TimerState*.swift`; transports
  `Services/TimerSyncTransport.swift`, `Services/HealthKitTimerSyncTransport.swift`; controller
  `Services/TimerSessionController.swift`; tests `Kraftli TimersTests/TimerState*Tests.swift`,
  `TimerSync*Tests.swift`, `TimerSessionControllerTests.swift` (incl. `FakeLink`).
