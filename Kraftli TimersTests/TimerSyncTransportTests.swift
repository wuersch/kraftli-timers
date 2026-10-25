//
//  TimerSyncTransportTests.swift
//  Kraftli TimersTests
//
//  Tests for the timer sync payload, inbox filtering and composite transport (ADR-006 §3).
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct TimerSyncTransportTests {

    // MARK: - Fixtures

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func makeState(workoutID: UUID = UUID(), revision: Int = 1) -> TimerState {
        var state = TimerState(
            workoutID: workoutID,
            owner: .watch,
            config: TimerConfig(
                timerKindRaw: TimerKind.emom.rawValue,
                totalDuration: 600,
                intervalCount: 10,
                exerciseName: "Burpees"
            ),
            now: t0
        )
        state.revision = revision
        return state
    }

    private func makeIntent(workoutID: UUID, action: TimerIntent.Action = .pause) -> TimerIntent {
        TimerIntent(workoutID: workoutID, baseRevision: 1, action: action, at: t0)
    }

    // MARK: - Payload

    @Test func payload_roundTripsThroughWatchConnectivityDictionary() throws {
        let state = makeState(revision: 7)
        let intents = [makeIntent(workoutID: state.workoutID), makeIntent(workoutID: state.workoutID, action: .stop)]

        #expect(TimerSyncPayload(dictionary: try TimerSyncPayload.state(state).dictionary()) == .state(state))
        #expect(TimerSyncPayload(dictionary: try TimerSyncPayload.intents(intents).dictionary()) == .intents(intents))
    }

    @Test func payload_ignoresLegacyWatchMessageDictionaries() throws {
        let legacy = try WatchMessageCoder.encode(StopTimerMessage(correlationID: UUID()))

        #expect(TimerSyncPayload(dictionary: legacy) == nil)
    }

    @Test func payload_roundTripsThroughData() throws {
        let payload = TimerSyncPayload.state(makeState(revision: 3))

        #expect(try TimerSyncPayload(data: payload.encoded()) == payload)
    }

    // MARK: - Inbox: snapshots

    @Test func inbox_acceptsOnlyHigherRevisions() {
        let workoutID = UUID()
        var inbox = TimerSyncInbox(workoutID: workoutID)

        let accepted = inbox.accept(makeState(workoutID: workoutID, revision: 2))
        #expect(accepted)
        let duplicate = inbox.accept(makeState(workoutID: workoutID, revision: 2))
        #expect(!duplicate)  // duplicate
        let late = inbox.accept(makeState(workoutID: workoutID, revision: 1))
        #expect(!late)  // late
        let afterGap = inbox.accept(makeState(workoutID: workoutID, revision: 5))
        #expect(afterGap)   // gap is fine
        #expect(inbox.latestRevision == 5)
    }

    @Test func inbox_rejectsOtherWorkouts() {
        var inbox = TimerSyncInbox(workoutID: UUID())

        let accepted = inbox.accept(makeState(workoutID: UUID(), revision: 99))
        #expect(!accepted)
    }

    @Test func inbox_withoutExpectedWorkout_acceptsNothing() {
        var inbox = TimerSyncInbox()

        let accepted = inbox.accept(makeState())
        #expect(!accepted)
    }

    @Test func inbox_expectNewWorkout_resetsRevisionTracking() {
        let first = UUID()
        let second = UUID()
        var inbox = TimerSyncInbox(workoutID: first)
        _ = inbox.accept(makeState(workoutID: first, revision: 9))

        inbox.expect(second)

        let newWorkout = inbox.accept(makeState(workoutID: second, revision: 1))
        #expect(newWorkout)
        let oldWorkout = inbox.accept(makeState(workoutID: first, revision: 10))
        #expect(!oldWorkout)  // old workout's late snapshot
    }

    // MARK: - Inbox: intents

    @Test func inbox_dropsAlreadySeenIntents_keepingOrder() {
        let workoutID = UUID()
        var inbox = TimerSyncInbox(workoutID: workoutID)
        let pause = makeIntent(workoutID: workoutID, action: .pause)
        let resume = makeIntent(workoutID: workoutID, action: .resume)

        let firstDelivery = inbox.accept([pause])
        #expect(firstDelivery == [pause])
        // The queued batch redelivers the pause together with the new resume.
        let afterRedelivery = inbox.accept([pause, resume])
        #expect(afterRedelivery == [resume])
        let afterSecondRedelivery = inbox.accept([pause, resume])
        #expect(afterSecondRedelivery.isEmpty)
    }

    @Test func inbox_dropsIntentsForOtherWorkouts() {
        var inbox = TimerSyncInbox(workoutID: UUID())

        let accepted = inbox.accept([makeIntent(workoutID: UUID())])
        #expect(accepted.isEmpty)
    }

    // MARK: - Composite

    @Test @MainActor func composite_publishesOnEveryChannel() {
        let healthKit = FakeTransport()
        let connectivity = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [healthKit, connectivity])
        let state = makeState()
        let intents = [makeIntent(workoutID: state.workoutID)]

        composite.publish(state)
        composite.send(intents)

        #expect(healthKit.published == [state] && connectivity.published == [state])
        #expect(healthKit.sent == [intents] && connectivity.sent == [intents])
    }

    @Test @MainActor func composite_deliversEachSnapshotOnce_acrossChannels() {
        let healthKit = FakeTransport()
        let connectivity = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [healthKit, connectivity])
        let workoutID = UUID()
        composite.expect(workoutID)
        var received: [TimerSyncPayload] = []
        composite.onPayload = { received.append($0) }

        let rev2 = makeState(workoutID: workoutID, revision: 2)
        let rev3 = makeState(workoutID: workoutID, revision: 3)
        healthKit.deliver(.state(rev2))
        connectivity.deliver(.state(rev2))  // same snapshot, second channel
        connectivity.deliver(.state(rev3))
        healthKit.deliver(.state(rev2))     // late redelivery

        #expect(received == [.state(rev2), .state(rev3)])
    }

    @Test @MainActor func composite_deliversOnlyFreshIntents() {
        let healthKit = FakeTransport()
        let connectivity = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [healthKit, connectivity])
        let workoutID = UUID()
        composite.expect(workoutID)
        var received: [TimerSyncPayload] = []
        composite.onPayload = { received.append($0) }
        let pause = makeIntent(workoutID: workoutID, action: .pause)
        let round = makeIntent(workoutID: workoutID, action: .incrementRound)

        healthKit.deliver(.intents([pause]))
        connectivity.deliver(.intents([pause, round]))  // queued copy arrives later

        #expect(received == [.intents([pause]), .intents([round])])
    }

    @Test @MainActor func composite_ignoresEchoOfOwnSnapshot() {
        let channel = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [channel])
        let state = makeState(revision: 4)
        composite.expect(state.workoutID)
        var received: [TimerSyncPayload] = []
        composite.onPayload = { received.append($0) }

        composite.publish(state)
        channel.deliver(.state(state))

        #expect(received.isEmpty)
    }

    // MARK: - Ownership precedence

    @Test func inbox_phoneSnapshotReplacesWatchSnapshot_evenAtSameRevision() {
        var inbox = TimerSyncInbox()
        let watchState = makeState(revision: 1)
        inbox.expect(watchState.workoutID)
        var phoneState = TimerState(workoutID: watchState.workoutID, owner: .phone, config: watchState.config, now: t0)
        phoneState.revision = 1

        var laterWatchState = watchState
        laterWatchState.revision = 5

        let acceptedWatch = inbox.accept(watchState)
        let acceptedPhone = inbox.accept(phoneState)          // the iPhone took over
        let acceptedLaterWatch = inbox.accept(laterWatchState) // a Watch that hasn't yielded yet

        #expect(acceptedWatch && acceptedPhone && !acceptedLaterWatch)
    }

    // MARK: - Start requests

    private func makeStartRequest() -> StartRequest {
        StartRequest(workoutID: UUID(), config: makeState().config, requestedAt: t0)
    }

    @Test func startRequestPayload_roundTripsThroughWatchConnectivityDictionary() throws {
        let payload = TimerSyncPayload.startRequest(makeStartRequest())

        #expect(TimerSyncPayload(dictionary: try payload.dictionary()) == payload)
    }

    @Test @MainActor func composite_sendsStartRequestOnEveryChannel() {
        let healthKit = FakeTransport()
        let connectivity = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [healthKit, connectivity])
        let request = makeStartRequest()

        composite.requestStart(request)

        #expect(healthKit.requestedStarts == [request] && connectivity.requestedStarts == [request])
    }

    @Test @MainActor func composite_deliversStartRequestOnce_evenAfterExpectingItsWorkout() {
        let healthKit = FakeTransport()
        let connectivity = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [healthKit, connectivity])
        var requests: [StartRequest] = []
        var payloads: [TimerSyncPayload] = []
        composite.onStartRequest = { requests.append($0) }
        composite.onPayload = { payloads.append($0) }
        let request = makeStartRequest()

        connectivity.deliver(.startRequest(request))
        composite.expect(request.workoutID)          // the receiver starts the workout
        healthKit.deliver(.startRequest(request))    // the copy from the other channel

        #expect(requests == [request])
        #expect(payloads.isEmpty)  // start requests never reach the session's payload handler
    }

    @Test @MainActor func composite_forwardsReconnectFromAnyChannel() {
        let healthKit = FakeTransport()
        let connectivity = FakeTransport()
        let composite = CompositeTimerSyncTransport(transports: [healthKit, connectivity])
        var reconnects = 0
        composite.onReconnect = { reconnects += 1 }

        connectivity.onReconnect?()
        healthKit.onReconnect?()

        #expect(reconnects == 2)
    }
}

// MARK: - Fake transport

@MainActor
private final class FakeTransport: TimerSyncTransport {
    var onPayload: ((TimerSyncPayload) -> Void)?
    var onReconnect: (() -> Void)?
    private(set) var published: [TimerState] = []
    private(set) var sent: [[TimerIntent]] = []
    private(set) var requestedStarts: [StartRequest] = []

    func publish(_ state: TimerState) { published.append(state) }
    func send(_ intents: [TimerIntent]) { sent.append(intents) }
    func requestStart(_ request: StartRequest) { requestedStarts.append(request) }

    /// Simulates a payload arriving from the other device on this channel.
    func deliver(_ payload: TimerSyncPayload) { onPayload?(payload) }
}
