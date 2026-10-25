//
//  TimerSyncTransport.swift
//  Kraftli Timers
//
//  Moves timer snapshots and viewer intents between iPhone and Watch (ADR-006 §3).
//  Shared by the iPhone and Watch targets.
//
//  ## Layers
//  - `TimerSyncPayload` — what travels: a state snapshot or a batch of intents,
//    encoded once as JSON so every transport carries identical bytes.
//  - `TimerSyncTransport` — one channel (HealthKit session data, WatchConnectivity).
//  - `CompositeTimerSyncTransport` — publishes on *all* channels and filters what
//    comes back through a `TimerSyncInbox`.
//
//  Redundancy is safe because applying a snapshot is idempotent: the inbox keeps
//  only the highest revision of the expected workout and drops intents it has
//  already seen, so a duplicate, late or reordered delivery never changes anything.
//

import Foundation
import os

// MARK: - Payload

/// Everything the timer sync protocol sends between devices.
nonisolated enum TimerSyncPayload: Codable, Equatable, Sendable {
    /// The owner's latest snapshot.
    case state(TimerState)
    /// Viewer intents for the owner, in the order the user made them.
    case intents([TimerIntent])
    /// The iPhone asking the Watch to start and own a workout.
    case startRequest(StartRequest)

    /// WatchConnectivity dictionary key for an encoded payload. Distinct from the
    /// legacy `WatchMessageCoder` keys, so old and new messages never collide.
    static let dictionaryKey = "timerSync"

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    /// The payload wrapped for WatchConnectivity's `[String: Any]` APIs.
    func dictionary() throws -> [String: Any] {
        [Self.dictionaryKey: try encoded()]
    }

    /// Decodes a WatchConnectivity dictionary, or returns nil if it isn't a timer sync payload.
    init?(dictionary: [String: Any]) {
        guard let data = dictionary[Self.dictionaryKey] as? Data,
              let payload = try? Self(data: data) else { return nil }
        self = payload
    }
}

// MARK: - Transport

/// One channel that carries timer sync payloads to the other device.
///
/// Incoming payloads are delivered on the main actor. Delivery is best-effort per
/// channel; reliability comes from publishing on several channels at once.
@MainActor
protocol TimerSyncTransport: AnyObject {
    /// Sends the owner's snapshot.
    func publish(_ state: TimerState)

    /// Sends viewer intents to the owner.
    func send(_ intents: [TimerIntent])

    /// Asks the other device to start and own a workout.
    func requestStart(_ request: StartRequest)

    /// Called for every payload this channel receives.
    var onPayload: ((TimerSyncPayload) -> Void)? { get set }

    /// Called when the channel (re)connects, so the owner can republish its latest snapshot.
    var onReconnect: (() -> Void)? { get set }
}

// MARK: - Inbox

/// Filters incoming payloads so that duplicates, stale snapshots and other
/// workouts' traffic never reach the session logic. Pure value type.
nonisolated struct TimerSyncInbox: Sendable {
    /// Only payloads for this workout are accepted; nil accepts nothing.
    private(set) var workoutID: UUID?
    private(set) var latestRevision = 0
    /// The owner of the latest accepted snapshot.
    private(set) var latestOwner: DeviceRole?
    private var seenIntentIDs: [UUID] = []
    /// The last start request delivered. Kept across `expect(_:)`, because a request
    /// arrives on several channels and the receiver starts expecting its workout after
    /// the first copy.
    private var lastStartRequestID: UUID?

    /// How many intent IDs are remembered for dedup (oldest dropped first).
    static let seenIntentIDLimit = 256

    init(workoutID: UUID? = nil) {
        self.workoutID = workoutID
    }

    /// Starts listening for a (new) workout, forgetting everything about the previous one.
    mutating func expect(_ workoutID: UUID?) {
        let lastStartRequestID = lastStartRequestID
        self = Self(workoutID: workoutID)
        self.lastStartRequestID = lastStartRequestID
    }

    /// Returns true if `state` is newer than anything seen for the expected workout.
    ///
    /// Ownership precedence: the iPhone arbitrates iPhone-started workouts (ADR-006 §4), so
    /// after a crossed handshake its snapshot replaces a Watch-owned one whatever the revisions.
    mutating func accept(_ state: TimerState) -> Bool {
        guard state.workoutID == workoutID else { return false }
        switch (latestOwner, state.owner) {
        case (.watch, .phone):
            break  // The iPhone took over.
        case (.phone, .watch):
            return false  // A Watch that hasn't yielded yet.
        default:
            guard state.revision > latestRevision else { return false }
        }
        latestRevision = state.revision
        latestOwner = state.owner
        return true
    }

    /// Returns the intents for the expected workout not seen before, in their original order.
    mutating func accept(_ intents: [TimerIntent]) -> [TimerIntent] {
        let fresh = intents.filter { $0.workoutID == workoutID && !seenIntentIDs.contains($0.id) }
        seenIntentIDs = Array((seenIntentIDs + fresh.map(\.id)).suffix(Self.seenIntentIDLimit))
        return fresh
    }

    /// Returns true for the first copy of a start request. Accepted whatever workout
    /// is expected, since a request is how a new workout begins.
    mutating func accept(_ request: StartRequest) -> Bool {
        guard request.workoutID != lastStartRequestID else { return false }
        lastStartRequestID = request.workoutID
        return true
    }
}

// MARK: - Composite

/// Publishes on every underlying channel and delivers each payload at most once.
@MainActor
final class CompositeTimerSyncTransport: TimerSyncTransport {
    private let transports: [any TimerSyncTransport]
    private var inbox = TimerSyncInbox()

    /// Receives snapshots and intents for the expected workout.
    var onPayload: ((TimerSyncPayload) -> Void)?
    var onReconnect: (() -> Void)?
    /// Receives start requests, which are separate from the running workout's traffic.
    var onStartRequest: ((StartRequest) -> Void)?

    init(transports: [any TimerSyncTransport]) {
        self.transports = transports
        for transport in transports {
            transport.onPayload = { [weak self] payload in self?.receive(payload) }
            transport.onReconnect = { [weak self] in self?.onReconnect?() }
        }
    }

    /// Accepts payloads for `workoutID` only, resetting revision and dedup tracking.
    func expect(_ workoutID: UUID?) {
        inbox.expect(workoutID)
    }

    func publish(_ state: TimerState) {
        // Our own snapshot counts as seen, so an echo of it is never delivered back.
        _ = inbox.accept(state)
        transports.forEach { $0.publish(state) }
    }

    func send(_ intents: [TimerIntent]) {
        transports.forEach { $0.send(intents) }
    }

    func requestStart(_ request: StartRequest) {
        transports.forEach { $0.requestStart(request) }
    }

    private func receive(_ payload: TimerSyncPayload) {
        switch payload {
        case .state(let state):
            guard inbox.accept(state) else { return }
            onPayload?(.state(state))
        case .intents(let intents):
            let fresh = inbox.accept(intents)
            guard !fresh.isEmpty else { return }
            onPayload?(.intents(fresh))
        case .startRequest(let request):
            guard inbox.accept(request) else { return }
            onStartRequest?(request)
        }
    }
}

// MARK: - WatchConnectivity

/// Carries timer sync payloads over WatchConnectivity:
/// - snapshots → application context (latest-wins, persisted: covers cold launches
///   and relaunches) plus `sendMessage` when reachable (low latency); the final
///   snapshot (with `finish`) also through `transferUserInfo`, so the end of a workout
///   reaches a viewer that was out of reach when it happened (ADR-006 §3);
/// - intents → `sendMessage` when reachable plus `transferUserInfo` (queued,
///   survives disconnects; duplicates are dropped by the inbox);
/// - start requests → like snapshots, so a Watch app launched by `startWatchApp`
///   finds the request in the context it reads on activation.
@MainActor
final class WatchConnectivityTimerSyncTransport: TimerSyncTransport {
    private let connectivity: WatchConnectivityService

    var onPayload: ((TimerSyncPayload) -> Void)?
    var onReconnect: (() -> Void)?

    init(connectivity: WatchConnectivityService = .shared) {
        self.connectivity = connectivity
        connectivity.onTimerSyncPayload = { [weak self] payload in self?.onPayload?(payload) }
        connectivity.onReachable = { [weak self] in self?.onReconnect?() }
    }

    func publish(_ state: TimerState) {
        guard let dictionary = encode(.state(state)) else { return }
        connectivity.updateApplicationContext(dictionary: dictionary)
        connectivity.sendMessage(dictionary: dictionary)
        if state.finish != nil {
            connectivity.transferUserInfo(dictionary: dictionary)
        }
    }

    func send(_ intents: [TimerIntent]) {
        guard let dictionary = encode(.intents(intents)) else { return }
        connectivity.sendMessage(dictionary: dictionary)
        connectivity.transferUserInfo(dictionary: dictionary)
    }

    func requestStart(_ request: StartRequest) {
        guard let dictionary = encode(.startRequest(request)) else { return }
        connectivity.updateApplicationContext(dictionary: dictionary)
        connectivity.sendMessage(dictionary: dictionary)
    }

    private func encode(_ payload: TimerSyncPayload) -> [String: Any]? {
        do {
            return try payload.dictionary()
        } catch {
            Logger.timerSync.error("Failed to encode timer sync payload: \(error.localizedDescription)")
            return nil
        }
    }
}
