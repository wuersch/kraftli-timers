//
//  WatchMessageCoordinator.swift
//  Kraftli Timers Watch App
//
//  Coordinates message handling between WatchConnectivity and the UI.
//  Sets up message handlers at app startup to ensure they're ready before
//  any messages arrive.
//

import Foundation
import os

/// Coordinates incoming messages from iPhone and routes them appropriately.
///
/// This coordinator is initialized at app startup to ensure message handlers
/// are ready before any messages arrive (fixing first-launch timing issues).
@Observable
final class WatchMessageCoordinator {
    /// The most recent timer start message from iPhone, waiting to be consumed.
    /// Set by `handleMessage` when a `StartTimerMessage` arrives, cleared by the
    /// UI after handling. Using a stored property instead of a Combine publisher
    /// avoids a race where messages arrive before any subscriber exists.
    var pendingStartTimer: StartTimerMessage?

    /// Deduplication: tracks the last StartTimerMessage handled and when it arrived.
    /// When dual-delivery (sendMessage + transferUserInfo) is used, the same message
    /// may arrive twice. We skip duplicates within a short window.
    private var lastHandledStartTimer: StartTimerMessage?
    private var lastHandledStartTimerDate: Date?
    private static let deduplicationWindow: TimeInterval = 10

    /// The active sync service for mirrored timer control messages.
    /// Set this when a mirrored timer is presented, clear when dismissed.
    var activeSyncService: DefaultWatchTimerSyncService? {
        didSet {
            Logger.timerSync.debug("Active sync service \(self.activeSyncService == nil ? "cleared" : "set")")
        }
    }

    init() {
        setupMessageHandling()
        Logger.timerSync.info("WatchMessageCoordinator initialized")
    }

    /// Sets up the message handler on WatchConnectivityService.
    /// Called once at init to ensure handler is ready from app launch.
    private func setupMessageHandling() {
        WatchConnectivityService.shared.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
    }

    /// Routes incoming messages to the appropriate handler.
    @MainActor
    private func handleMessage(_ message: WatchMessage) {
        switch message {
        case let startTimer as StartTimerMessage:
            // Deduplicate: dual-delivery (sendMessage + transferUserInfo) may deliver
            // the same StartTimerMessage twice. Skip if we handled an identical message
            // within the deduplication window.
            if let last = lastHandledStartTimer,
               let lastDate = lastHandledStartTimerDate,
               last == startTimer,
               Date().timeIntervalSince(lastDate) < Self.deduplicationWindow {
                Logger.timerSync.debug("Skipping duplicate StartTimerMessage: \(startTimer.exerciseName)")
                return
            }

            lastHandledStartTimer = startTimer
            lastHandledStartTimerDate = Date()
            Logger.timerSync.info("Received StartTimerMessage: \(startTimer.exerciseName)")
            pendingStartTimer = startTimer

        case let control as TimerControlMessage:
            Logger.timerSync.debug("Received TimerControlMessage: \(String(describing: control.action))")
            // Forward to the active sync service if one exists
            if let syncService = activeSyncService {
                syncService.handleControlMessage(control)
            } else {
                Logger.timerSync.warning("Received control message but no active sync service")
            }

        default:
            Logger.timerSync.warning("Received unknown message type")
        }
    }
}
