//
//  TimerSessionController.swift
//  Kraftli Timers
//
//  Runs one workout's timer state on one device, as its owner or as a viewer
//  (ADR-006, ADR-007). Shared by the iPhone and Watch targets.
//
//  ## Owner
//  Holds the authoritative `TimerState`. Every change — a local tap or an intent
//  from the viewer — goes through `TimerStateReducer` and is published as a new
//  revision. The owner also marks the workout completed when the time runs out
//  and republishes its latest snapshot whenever a channel reconnects.
//
//  ## Viewer
//  Keeps the owner's last *confirmed* snapshot plus the intents it sent that the
//  owner hasn't processed yet (*pending*). It renders `confirmed + pending`,
//  predicted with the same reducer the owner uses, so a tap takes effect on screen
//  immediately even while the owner is unreachable. Each tap resends the whole
//  pending list; the owner and the inbox drop duplicates by intent ID, so a list
//  built up offline arrives as one ordered batch. A pending intent leaves the list
//  once a snapshot lists it in `handledIntentIDs` — applied or rejected.
//
//  ## Observing it
//  `renderedState` is what the UI should show. It's an `@Observable` property, and
//  `onRenderedStateChange` lets a timer model adopt every new value via `apply(_:)`.
//

import Foundation
import os

@Observable
@MainActor
final class TimerSessionController {
    enum Role: Equatable {
        case owner
        case viewer
    }

    // MARK: - Observable State

    /// This device's role for the current workout; nil when no workout is active.
    private(set) var role: Role?

    /// The owner's latest snapshot as this device knows it. On the owner this is the
    /// authoritative state; on the viewer, the last one received.
    private(set) var confirmedState: TimerState?

    /// Viewer intents not yet processed by the owner, in the order they were made.
    private(set) var pendingIntents: [TimerIntent] = []

    /// What the UI shows: the confirmed state with any pending intents predicted on top.
    private(set) var renderedState: TimerState?

    /// When the owner last overruled a pause/resume this viewer had predicted (ADR-007).
    /// The UI shows a short "Synced with …" hint when this changes.
    private(set) var lastRollbackDate: Date?

    /// True while this viewer has changes the owner hasn't confirmed yet.
    var hasUnconfirmedChanges: Bool {
        !pendingIntents.isEmpty
    }

    // MARK: - Callbacks

    /// Called with every new `renderedState`, e.g. to feed a timer model's `apply(_:)`.
    @ObservationIgnored var onRenderedStateChange: ((TimerState) -> Void)?

    // MARK: - Dependencies

    @ObservationIgnored private let transport: CompositeTimerSyncTransport
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let schedulesCompletion: Bool
    @ObservationIgnored private var completionTask: Task<Void, Never>?

    /// - Parameters:
    ///   - transport: The channels to the other device.
    ///   - now: Wall-clock source. Injectable so tests can drive time deterministically.
    ///   - schedulesCompletion: Whether the owner schedules its own completion check at the
    ///     workout's end time. Tests turn it off and call `checkCompletion()` directly.
    init(
        transport: CompositeTimerSyncTransport,
        now: @escaping () -> Date = { Date() },
        schedulesCompletion: Bool = true
    ) {
        self.transport = transport
        self.now = now
        self.schedulesCompletion = schedulesCompletion
        transport.onPayload = { [weak self] payload in self?.receive(payload) }
        transport.onReconnect = { [weak self] in self?.reconnected() }
    }

    // MARK: - Lifecycle

    /// Takes ownership of a new workout and publishes its first snapshot.
    func startAsOwner(_ state: TimerState) {
        reset(for: state.workoutID, role: .owner)
        commit(state)
    }

    /// Starts following a workout owned by the other device. Rendering begins with
    /// the first snapshot that arrives for `workoutID`.
    func startAsViewer(workoutID: UUID) {
        reset(for: workoutID, role: .viewer)
    }

    /// Stops following or owning the current workout. Later traffic for it is ignored.
    func end() {
        completionTask?.cancel()
        completionTask = nil
        transport.expect(nil)
        role = nil
        confirmedState = nil
        pendingIntents = []
        renderedState = nil
    }

    // MARK: - Actions (either role)

    func pause() { act(.pause) }
    func resume() { act(.resume) }
    func incrementRound() { act(.incrementRound) }
    func stop() { act(.stop) }

    /// Owner only: marks the workout completed if its time has run out.
    /// Normally scheduled automatically; exposed for tests.
    func checkCompletion() {
        guard role == .owner, let state = confirmedState,
              let completed = TimerStateReducer.completingIfDue(state, now: now()) else { return }
        commit(completed)
    }

    // MARK: - Private

    private func reset(for workoutID: UUID, role: Role) {
        completionTask?.cancel()
        completionTask = nil
        transport.expect(workoutID)
        self.role = role
        confirmedState = nil
        pendingIntents = []
        renderedState = nil
    }

    private func act(_ action: TimerIntent.Action) {
        // A viewer can't act before it knows the owner's state: there's no base revision yet.
        guard let role, let confirmed = confirmedState else { return }
        let isPauseAction = action == .pause || action == .resume
        let intent = TimerIntent(
            workoutID: confirmed.workoutID,
            baseRevision: confirmed.revision,
            action: action,
            at: now(),
            // Chain to our own unconfirmed pause/resume, so the owner doesn't mistake it
            // for a conflict if the two arrive in separate deliveries.
            previousPauseIntentID: isPauseAction
                ? pendingIntents.last { $0.action == .pause || $0.action == .resume }?.id
                : nil
        )
        switch role {
        case .owner:
            apply([intent])
        case .viewer:
            pendingIntents.append(intent)
            transport.send(pendingIntents)
            render()
        }
    }

    /// Owner: applies intents and publishes the result if anything changed.
    private func apply(_ intents: [TimerIntent]) {
        guard let state = confirmedState else { return }
        let next = TimerStateReducer.apply(intents, to: state, now: now())
        guard next != state else { return }
        commit(next)
    }

    /// Owner: adopts and publishes a new authoritative state.
    private func commit(_ state: TimerState) {
        confirmedState = state
        transport.publish(state)
        render()
        scheduleCompletionCheck()
    }

    private func receive(_ payload: TimerSyncPayload) {
        switch (role, payload) {
        case (.owner, .intents(let intents)):
            apply(intents)
        case (.viewer, .state(let state)):
            adoptConfirmed(state)
        case (.owner, .state(let state)):
            // Two owners for one workout can only come from a crossed start handshake,
            // which step 5's yield rule resolves. Until then, keep our own state.
            Logger.timerSync.warning("Owner received a snapshot (revision \(state.revision)) for its own workout; ignoring")
        case (.viewer, .intents), (nil, _):
            break
        }
    }

    /// Viewer: takes a newer snapshot from the owner and re-predicts pending intents on top.
    private func adoptConfirmed(_ state: TimerState) {
        let predictedPaused = renderedState?.isPaused
        let hadPendingPauseState = pendingIntents.contains { $0.action == .pause || $0.action == .resume }
        pendingIntents.removeAll { state.handledIntentIDs.contains($0.id) }
        confirmedState = state
        render()

        // A rollback: what we showed depended on our own pause/resume, and the owner's newer
        // state contradicts it — the owner won (ADR-007 §3). This can surface before the owner
        // has even processed our intent, because the prediction already accounts for the conflict.
        if hadPendingPauseState, let predictedPaused, predictedPaused != renderedState?.isPaused {
            lastRollbackDate = now()
            Logger.timerSync.info("Owner overruled a predicted pause/resume; snapped to revision \(state.revision)")
        }
    }

    private func render() {
        guard let confirmed = confirmedState else {
            renderedState = nil
            return
        }
        let rendered = pendingIntents.isEmpty
            ? confirmed
            : TimerStateReducer.apply(pendingIntents, to: confirmed, now: now())
        renderedState = rendered
        onRenderedStateChange?(rendered)
    }

    private func reconnected() {
        switch role {
        case .owner:
            if let state = confirmedState {
                transport.publish(state)
            }
        case .viewer:
            if !pendingIntents.isEmpty {
                transport.send(pendingIntents)
            }
        case nil:
            break
        }
    }

    /// Owner: wakes up at the workout's end time to mark it completed.
    private func scheduleCompletionCheck() {
        completionTask?.cancel()
        completionTask = nil
        guard schedulesCompletion, role == .owner, let state = confirmedState,
              state.finish == nil, !state.isPaused else { return }
        let endDate = state.startDate.addingTimeInterval(state.accumulatedPause + state.config.totalDuration)
        let delay = max(0, endDate.timeIntervalSince(now()))
        completionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.checkCompletion()
        }
    }
}
