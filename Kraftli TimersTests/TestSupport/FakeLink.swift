//
//  FakeLink.swift
//  Kraftli TimersTests
//
//  A simulated iPhone ↔ Watch connection for timer sync tests (ADR-006).
//

import Foundation
@testable import Kraftli_Timers

// MARK: - Fake link

/// Two connected transport endpoints that behave like the real channels:
/// - connected: everything is delivered immediately;
/// - disconnected: immediate messages are lost, only the latest snapshot or start
///   request is kept (the one application-context slot) and intents are queued
///   (`transferUserInfo`);
/// - reconnecting delivers the kept context and the queue, then signals `onReconnect`.
@MainActor
final class FakeLink {
    final class End: TimerSyncTransport {
        var onPayload: ((TimerSyncPayload) -> Void)?
        var onReconnect: (() -> Void)?
        weak var link: FakeLink?
        weak var peer: End?
        private(set) var sentCount = 0

        fileprivate var latestContextWhileOffline: TimerSyncPayload?
        fileprivate var queuedIntents: [[TimerIntent]] = []

        func publish(_ state: TimerState) {
            transmit(.state(state))
        }

        func send(_ intents: [TimerIntent]) {
            sentCount += 1
            transmit(.intents(intents))
        }

        func requestStart(_ request: StartRequest) {
            transmit(.startRequest(request))
        }

        private func transmit(_ payload: TimerSyncPayload) {
            guard let peer, let link else { return }
            if link.isConnected {
                peer.onPayload?(payload)
                return
            }
            switch payload {
            case .state, .startRequest: latestContextWhileOffline = payload
            case .intents(let intents): queuedIntents.append(intents)
            }
        }

        fileprivate func flush() {
            if let context = latestContextWhileOffline {
                peer?.onPayload?(context)
            }
            for intents in queuedIntents {
                peer?.onPayload?(.intents(intents))
            }
            latestContextWhileOffline = nil
            queuedIntents = []
        }
    }

    let watchEnd = End()
    let phoneEnd = End()

    var isConnected = true {
        didSet {
            guard isConnected, !oldValue else { return }
            watchEnd.flush()
            phoneEnd.flush()
            watchEnd.onReconnect?()
            phoneEnd.onReconnect?()
        }
    }

    init() {
        watchEnd.link = self
        phoneEnd.link = self
        watchEnd.peer = phoneEnd
        phoneEnd.peer = watchEnd
    }
}
