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

    #if os(iOS)
    /// Sends a message to Watch for immediate delivery.
    ///
    /// Uses WCSession.sendMessage for real-time communication when Watch is reachable.
    /// This is ideal for time-sensitive actions like starting a timer.
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
            completion?(.failure(WatchConnectivityError.watchNotReachable))
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

    /// Queues a message for reliable background delivery to Watch.
    ///
    /// Unlike `sendMessage`, this works even when the Watch app is not reachable.
    /// The system queues the transfer and delivers it when the Watch becomes available.
    /// Use this alongside `sendMessage` for critical messages like `StartTimerMessage`.
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
            Logger.watchConnectivity.debug("Queued user info transfer: \(message.messageType.rawValue)")
        } catch {
            Logger.watchConnectivity.error("Failed to encode user info: \(error.localizedDescription)")
        }
    }

    /// Called when a real-time message is received from Watch.
    /// Used for timer control messages (play/pause/stop) from mirrored timers.
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
    /// Called when a real-time message is received from iPhone.
    /// Used for immediate actions like starting a timer.
    var onMessageReceived: ((WatchMessage) -> Void)?

    /// Sends a message to iPhone for immediate delivery.
    ///
    /// Used for timer control messages (play/pause/stop) from mirrored timers.
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

    private func handleReceivedMessage(_ dictionary: [String: Any]) {
        do {
            let message = try WatchMessageCoder.decode(dictionary)
            DispatchQueue.main.async { [weak self] in
                self?.onMessageReceived?(message)
            }
        } catch {
            Logger.watchConnectivity.error("Failed to decode message from iPhone: \(error.localizedDescription)")
        }
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
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for switching watches
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleReceivedMessage(message)
        // Send empty reply to acknowledge receipt
        replyHandler([:])
    }
    #endif

    #if os(watchOS)
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleReceivedMessage(message)
        // Send empty reply to acknowledge receipt
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleReceivedMessage(userInfo)
    }
    #endif
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
