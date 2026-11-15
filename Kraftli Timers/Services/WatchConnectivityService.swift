//
//  WatchConnectivityService.swift
//  Kraftli Timers
//
//  Provides real-time timer messaging between iPhone and Watch using WatchConnectivity.
//  Preset data syncs via CloudKit; this service handles timer control messages only.
//

import Foundation
import WatchConnectivity
import os

/// Manages WatchConnectivity session for real-time timer messaging.
///
/// Both devices exchange timer sync payloads (ADR-006) through the raw dictionary methods.
/// The Watch also sends the iPhone its end-of-workout HealthKit summary as a `WatchMessage`.
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private var session: WCSession?

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
    /// Sends a message to iPhone for immediate delivery if it is reachable. Best-effort:
    /// pair it with `transferUserInfo(_:)` for messages that must arrive.
    func sendMessage(_ message: WatchMessage) {
        guard let session,
              session.activationState == .activated,
              session.isReachable else {
            return
        }

        do {
            let encoded = try WatchMessageCoder.encode(message)
            session.sendMessage(encoded, replyHandler: nil) { error in
                Logger.watchConnectivity.debug("Immediate send to iPhone failed: \(error.localizedDescription)")
            }
        } catch {
            Logger.watchConnectivity.error("Failed to encode message: \(error.localizedDescription)")
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
        guard let session, session.activationState == .activated else {
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
        guard session.isReachable else { return }
        DispatchQueue.main.async {
            self.onReachable?()
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
