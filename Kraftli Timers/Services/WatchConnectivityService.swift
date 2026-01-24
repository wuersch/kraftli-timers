//
//  WatchConnectivityService.swift
//  Kraftli Timers
//
//  Provides real-time sync between iPhone and Watch using WatchConnectivity.
//  Supplements CloudKit sync with immediate updates when devices are paired.
//

import Foundation
import Combine
import WatchConnectivity
import os

/// Manages WatchConnectivity session for real-time preset sync.
///
/// On iOS: Sends preset updates to Watch when edited.
/// On watchOS: Receives preset updates and can send workout completions.
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
    /// Sends updated presets to Watch via application context.
    ///
    /// Application context is ideal for preset sync because:
    /// - Only the latest state is kept (previous updates are replaced)
    /// - Delivered when Watch becomes reachable if not immediately available
    func sendPresetsToWatch(_ presets: [PresetTransferData]) {
        guard let session = session, session.activationState == .activated else { return }

        let data: [[String: Any]] = presets.map { preset in
            var dict: [String: Any] = [
                "id": preset.id.uuidString,
                "kind": preset.kind,
                "duration": preset.duration,
                "sortOrder": preset.sortOrder
            ]
            if let reps = preset.targetReps {
                dict["targetReps"] = reps
            }
            if let exerciseName = preset.exerciseName {
                dict["exerciseName"] = exerciseName
            }
            return dict
        }

        do {
            try session.updateApplicationContext(["presets": data])
        } catch {
            Logger.watchConnectivity.error("Failed to send presets to Watch: \(error.localizedDescription)")
        }
    }

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
    /// Called when presets are received from iPhone.
    /// Override point for subclasses or set a callback.
    var onPresetsReceived: (([PresetTransferData]) -> Void)?

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

    private func handleReceivedPresets(_ data: [[String: Any]]) {
        let presets = data.compactMap { dict -> PresetTransferData? in
            guard
                let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let kind = dict["kind"] as? String,
                let duration = dict["duration"] as? TimeInterval,
                let sortOrder = dict["sortOrder"] as? Int
            else { return nil }

            return PresetTransferData(
                id: id,
                kind: kind,
                duration: duration,
                targetReps: dict["targetReps"] as? Int,
                exerciseName: dict["exerciseName"] as? String,
                sortOrder: sortOrder
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.onPresetsReceived?(presets)
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

        #if os(watchOS)
        // Check for any context sent before the app launched
        let context = session.receivedApplicationContext
        if let presetsData = context["presets"] as? [[String: Any]] {
            handleReceivedPresets(presetsData)
        }
        #endif
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
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if let presetsData = applicationContext["presets"] as? [[String: Any]] {
            handleReceivedPresets(presetsData)
        }
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

// MARK: - Transfer Data Model

/// Lightweight struct for transferring preset data over WatchConnectivity.
struct PresetTransferData {
    let id: UUID
    let kind: String
    let duration: TimeInterval
    let targetReps: Int?
    let exerciseName: String?
    let sortOrder: Int
}

#if os(iOS)
extension PresetTransferData {
    init(from preset: TimerPreset) {
        self.id = preset.id
        self.kind = preset.kindRawValue
        self.duration = preset.durationInterval
        self.targetReps = preset.targetReps
        self.exerciseName = preset.exercise?.name
        self.sortOrder = preset.sortOrder
    }
}
#endif
