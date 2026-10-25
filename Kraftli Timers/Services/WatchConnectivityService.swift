//
//  WatchConnectivityService.swift
//  Kraftli Timers
//
//  Provides real-time timer messaging between iPhone and Watch using WatchConnectivity.
//  Preset data syncs via CloudKit; this service handles timer control messages only.
//

import Foundation
import Combine
import WatchConnectivity
import os

/// Manages WatchConnectivity session for real-time timer messaging.
///
/// On iOS: Sends and receives timer control messages (start/pause/stop).
/// On watchOS: Sends and receives timer control messages.
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    private var session: WCSession?

    /// Whether the Watch is paired and reachable for immediate communication.
    @Published private(set) var isReachable = false

    private override init() {
        super.init()
    }

    /// Activates the WatchConnectivity session if supported.
    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Timer Sync (ADR-006)

    /// Called on the main queue for every received timer sync payload (snapshot or intents).
    /// Owned by `WatchConnectivityTimerSyncTransport`; legacy `WatchMessage`s keep using
    /// `onMessageReceived`.
    var onTimerSyncPayload: ((TimerSyncPayload) -> Void)?

    /// Called on the main queue when the counterpart becomes reachable again.
    var onReachable: (() -> Void)?

    /// Sends a raw dictionary for immediate delivery if the counterpart is reachable. Best-effort.
    func sendMessage(dictionary: [String: Any]) {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(dictionary, replyHandler: nil) { error in
            Logger.watchConnectivity.debug("Timer sync sendMessage failed: \(error.localizedDescription)")
        }
    }

    /// Publishes a raw dictionary as the application context (latest-wins, persisted).
    func updateApplicationContext(dictionary: [String: Any]) {
        guard let session, session.activationState == .activated else {
            Logger.watchConnectivity.warning("Cannot update application context: session not activated")
            return
        }
        do {
            try session.updateApplicationContext(dictionary)
        } catch {
            Logger.watchConnectivity.error("Failed to update application context: \(error.localizedDescription)")
        }
    }

    /// Queues a raw dictionary for guaranteed, in-order background delivery.
    func transferUserInfo(dictionary: [String: Any]) {
        guard let session, session.activationState == .activated else {
            Logger.watchConnectivity.warning("Cannot transfer user info: session not activated")
            return
        }
        session.transferUserInfo(dictionary)
    }

    /// Routes a received dictionary: timer sync payloads to `onTimerSyncPayload`,
    /// everything else to the legacy `WatchMessage` decoder.
    private func route(_ dictionary: [String: Any]) {
        if let payload = TimerSyncPayload(dictionary: dictionary) {
            DispatchQueue.main.async { [weak self] in
                self?.onTimerSyncPayload?(payload)
            }
        } else {
            handleReceivedMessage(dictionary)
        }
    }

    #if os(iOS)
    /// Whether a paired Watch has the app installed, i.e. whether a workout can start
    /// there at all (ADR-006 §4). False until the session has activated.
    var isWatchAppAvailable: Bool {
        guard let session, session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    /// Called with every `WatchMessage` from the Watch (the end-of-workout HealthKit summary).
    var onMessageReceived: ((WatchMessage) -> Void)?

    private func handleReceivedMessage(_ dictionary: [String: Any]) {
        do {
            let message = try WatchMessageCoder.decode(dictionary)
            DispatchQueue.main.async { [weak self] in
                self?.onMessageReceived?(message)
            }
        } catch {
            Logger.watchConnectivity.error("Failed to decode message from Watch: \(error.localizedDescription)")
        }
    }
    #endif

    #if os(watchOS)
    /// Sends a message to iPhone for immediate delivery.
    ///
    /// - Parameters:
    ///   - message: The message to send
    ///   - completion: Called with success/failure result
    func sendMessage(
        _ message: WatchMessage,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        guard let session = session,
              session.activationState == .activated,
              session.isReachable else {
            completion?(.failure(WatchConnectivityError.iPhoneNotReachable))
            return
        }

        do {
            let encoded = try WatchMessageCoder.encode(message)
            session.sendMessage(encoded, replyHandler: { _ in
                completion?(.success(()))
            }, errorHandler: { error in
                completion?(.failure(error))
            })
        } catch {
            completion?(.failure(error))
        }
    }

    /// Queues a message for reliable background delivery to iPhone.
    ///
    /// Unlike `sendMessage`, this works even when the iPhone app is not reachable.
    /// The system queues the transfer and delivers it when iPhone becomes available.
    /// Use this alongside `sendMessage` for critical messages like `WorkoutSessionEndedMessage`.
    ///
    /// - Parameter message: The message to transfer
    func transferUserInfo(_ message: WatchMessage) {
        guard let session = session,
              session.activationState == .activated else {
            Logger.watchConnectivity.warning("Cannot transfer user info: session not activated")
            return
        }

        do {
            let encoded = try WatchMessageCoder.encode(message)
            session.transferUserInfo(encoded)
            Logger.watchConnectivity.debug("Queued user info transfer to iPhone: \(message.messageType.rawValue)")
        } catch {
            Logger.watchConnectivity.error("Failed to encode user info: \(error.localizedDescription)")
        }
    }

    /// The iPhone sends only timer sync payloads (ADR-006); anything else comes from an
    /// older app version.
    private func handleReceivedMessage(_ dictionary: [String: Any]) {
        Logger.watchConnectivity.info("Ignoring a non-timer-sync message from iPhone")
    }

    #endif
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        // Consume any application context that arrived while the app wasn't
        // running — the cold-launch path: e.g. startWatchApp(toHandle:) opens the
        // Watch app, and the persisted context holds the current timer command or
        // snapshot. Duplicates with the sendMessage fast path are absorbed by the
        // coordinator's dedup (legacy) or the timer sync inbox (ADR-006).
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                route(context)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async {
            self.isReachable = reachable
            if reachable {
                self.onReachable?()
            }
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for switching watches
        session.activate()
    }
    #endif

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        route(message)
        // Send empty reply to acknowledge receipt
        replyHandler([:])
    }

    /// Messages sent without a reply handler (the timer sync fast path) arrive here.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        route(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        route(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        route(applicationContext)
    }
}

// MARK: - Errors

enum WatchConnectivityError: Error, LocalizedError {
    case watchNotReachable
    case iPhoneNotReachable

    var errorDescription: String? {
        switch self {
        case .watchNotReachable:
            return "Apple Watch is not reachable"
        case .iPhoneNotReachable:
            return "iPhone is not reachable"
        }
    }
}
