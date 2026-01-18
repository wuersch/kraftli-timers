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
            print("Failed to send presets to Watch: \(error)")
        }
    }
    #endif

    #if os(watchOS)
    /// Called when presets are received from iPhone.
    /// Override point for subclasses or set a callback.
    var onPresetsReceived: (([PresetTransferData]) -> Void)?

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
    #endif
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
