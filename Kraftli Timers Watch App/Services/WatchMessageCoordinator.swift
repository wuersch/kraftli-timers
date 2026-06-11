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

    /// Correlation ID of the currently active timer.
    /// Used to validate incoming `StopTimerMessage` — only stops matching
    /// the active timer (or with nil correlation) are applied.
    var activeCorrelationID: UUID?

    /// Reference to the workout session manager for orphaned stop handling.
    /// Set by the app entry point after both coordinator and manager are created.
    var sessionManager: WorkoutSessionManager?

    /// Deduplication for `StopTimerMessage` (dual delivery may arrive twice).
    /// Identity-based like the start dedup: only an *identical* stop within the
    /// window is skipped, so two legitimate stops in quick succession both apply.
    private var lastHandledStop: StopTimerMessage?
    private var lastHandledStopDate: Date?

    /// Correlation IDs of timers that have already been stopped.
    /// A late-arriving start command for one of these IDs must be ignored
    /// (it describes a workout the user already ended).
    private var stoppedCorrelationIDs: Set<UUID> = []

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

        case let stopMessage as StopTimerMessage:
            handleStopTimerMessage(stopMessage)

        default:
            Logger.timerSync.warning("Received unknown message type")
        }
    }

    // MARK: - Stop Timer Handling

    /// Handles a reliable stop message from iPhone.
    ///
    /// This arrives via `transferUserInfo` (queued delivery) and/or `sendMessage`
    /// (immediate delivery). Correlation ID matching prevents stale stops from
    /// killing a new timer that started after the original one completed.
    @MainActor
    private func handleStopTimerMessage(_ message: StopTimerMessage) {
        // Deduplicate within a short window (stop may arrive via two delivery
        // paths). Identity-based: a *different* stop within the window is a new,
        // legitimate command and must still apply.
        if let last = lastHandledStop,
           let lastDate = lastHandledStopDate,
           last == message,
           Date().timeIntervalSince(lastDate) < Self.deduplicationWindow {
            Logger.timerSync.debug("Skipping duplicate StopTimerMessage")
            return
        }
        lastHandledStop = message
        lastHandledStopDate = Date()

        if let stoppedID = message.correlationID {
            stoppedCorrelationIDs.insert(stoppedID)
        }

        if let syncService = activeSyncService {
            // Timer view is showing — check correlation before forwarding
            if message.correlationID == nil || message.correlationID == activeCorrelationID {
                Logger.timerSync.info("StopTimerMessage matches active timer, forwarding stop")
                syncService.handleControlMessage(TimerControlMessage(action: .stop))
            } else {
                Logger.timerSync.info("StopTimerMessage correlationID mismatch (stop: \(message.correlationID?.uuidString ?? "nil"), active: \(self.activeCorrelationID?.uuidString ?? "nil")), ignoring stale stop")
            }
        } else {
            // No timer view showing — handle as orphaned stop
            Logger.timerSync.info("StopTimerMessage received with no active timer, cleaning up orphaned session")
            handleOrphanedStop()
        }
    }

    /// Ends an orphaned HKWorkoutSession when no timer view is active.
    ///
    /// This handles the case where iPhone sent a stop but the Watch timer view
    /// was already dismissed (or was never shown). The HK session may still be
    /// active, preventing the user from closing the Watch app.
    @MainActor
    private func handleOrphanedStop() {
        guard let sessionManager, sessionManager.sessionState != .idle else { return }

        Logger.timerSync.info("Ending orphaned workout session (state: \(String(describing: sessionManager.sessionState)))")
        Task {
            _ = await sessionManager.endSession()
            sessionManager.resetToIdle()
        }
    }
}
