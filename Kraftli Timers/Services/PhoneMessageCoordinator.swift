//
//  PhoneMessageCoordinator.swift
//  Kraftli Timers
//
//  Coordinates incoming Watch messages on iPhone, mirroring the Watch's
//  WatchMessageCoordinator pattern. Created once at app startup so the
//  message handler exists for the whole app lifetime — messages that arrive
//  after a timer view is dismissed (e.g. a queued WorkoutSessionEndedMessage)
//  are no longer dropped.
//

import Foundation
import SwiftData
import os

/// Routes messages from the Watch to the active timer's sync service and
/// applies app-level effects that must not depend on a view being alive.
///
/// This is the *only* writer of `WatchConnectivityService.onMessageReceived`.
/// `DefaultTimerSyncService` instances are side-effect-free; the currently
/// presented timer registers its service here so control messages reach its
/// Combine publishers.
@Observable
final class PhoneMessageCoordinator {
    /// The sync service of the currently presented timer runner, if any.
    /// Set when a timer is presented, cleared when dismissed.
    var activeSyncService: DefaultTimerSyncService?

    /// Model context for WorkoutLog updates. Updating the log with the Watch's
    /// HealthKit UUID happens here — not in the view — so a message arriving
    /// after the runner view is gone still lands.
    var modelContext: ModelContext?

    /// Deduplication: dual delivery (sendMessage + transferUserInfo) may deliver
    /// the same WorkoutSessionEndedMessage twice. Skip identical messages within
    /// a short window.
    private var lastHandledSessionEnded: WorkoutSessionEndedMessage?
    private var lastHandledSessionEndedDate: Date?
    private static let deduplicationWindow: TimeInterval = 10

    init() {
        WatchConnectivityService.shared.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
        Logger.timerSync.info("PhoneMessageCoordinator initialized")
    }

    /// Routes an incoming message. Internal so tests can invoke it directly.
    @MainActor
    func handleMessage(_ message: WatchMessage) {
        if let endedMessage = message as? WorkoutSessionEndedMessage {
            if let last = lastHandledSessionEnded,
               let lastDate = lastHandledSessionEndedDate,
               last == endedMessage,
               Date().timeIntervalSince(lastDate) < Self.deduplicationWindow {
                Logger.timerSync.debug("Skipping duplicate WorkoutSessionEndedMessage")
                return
            }
            lastHandledSessionEnded = endedMessage
            lastHandledSessionEndedDate = Date()

            updateLogWithWatchUUID(endedMessage)
        }

        activeSyncService?.handleMessage(message)
    }

    /// Updates a WorkoutLog with the Watch's HealthKit UUID.
    ///
    /// Uses the correlation ID for exact matching when available; falls back to
    /// the most recent log without a UUID if the correlation ID is missing
    /// (backwards compatibility).
    @MainActor
    private func updateLogWithWatchUUID(_ endedMessage: WorkoutSessionEndedMessage) {
        guard let watchUUID = endedMessage.healthKitWorkoutUUID else { return }
        guard let modelContext else {
            Logger.healthKit.warning("WorkoutSessionEndedMessage arrived before modelContext was wired")
            return
        }

        if let correlationID = endedMessage.correlationID {
            // Exact match by WorkoutLog ID
            let descriptor = FetchDescriptor<WorkoutLog>(
                predicate: #Predicate { $0.id == correlationID }
            )
            guard let log = try? modelContext.fetch(descriptor).first,
                  log.healthKitWorkoutUUID == nil else {
                return
            }
            log.healthKitWorkoutUUID = watchUUID
            try? modelContext.save()
            Logger.healthKit.info("Updated workout log \(correlationID) with Watch HealthKit UUID: \(watchUUID)")
        } else {
            // Fallback: match most recent log without a UUID
            let descriptor = FetchDescriptor<WorkoutLog>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            guard let logs = try? modelContext.fetch(descriptor),
                  let latestLog = logs.first,
                  latestLog.healthKitWorkoutUUID == nil else {
                return
            }
            latestLog.healthKitWorkoutUUID = watchUUID
            try? modelContext.save()
            Logger.healthKit.info("Updated latest workout log with Watch HealthKit UUID: \(watchUUID) (no correlation ID)")
        }
    }
}
