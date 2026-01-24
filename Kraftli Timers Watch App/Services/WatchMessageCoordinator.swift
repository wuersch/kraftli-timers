//
//  WatchMessageCoordinator.swift
//  Kraftli Timers Watch App
//
//  Coordinates message handling between WatchConnectivity and the UI.
//  Sets up message handlers at app startup to ensure they're ready before
//  any messages arrive.
//

import Foundation
import Combine
import os

/// Coordinates incoming messages from iPhone and routes them appropriately.
///
/// This coordinator is initialized at app startup to ensure message handlers
/// are ready before any messages arrive (fixing first-launch timing issues).
@Observable
final class WatchMessageCoordinator {
    /// Publisher for timer start messages from iPhone.
    /// Subscribe to this to receive notifications when iPhone starts a timer.
    private let startTimerSubject = PassthroughSubject<StartTimerMessage, Never>()
    var startTimerReceived: AnyPublisher<StartTimerMessage, Never> {
        startTimerSubject.eraseToAnyPublisher()
    }

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
            Logger.timerSync.info("Received StartTimerMessage: \(startTimer.exerciseName)")
            startTimerSubject.send(startTimer)

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
