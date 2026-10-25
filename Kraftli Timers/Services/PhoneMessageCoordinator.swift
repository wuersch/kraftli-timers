//
//  PhoneMessageCoordinator.swift
//  Kraftli Timers
//
//  Handles the Watch's end-of-workout message on iPhone. Created once at app
//  startup so the handler exists for the whole app lifetime — a message that
//  arrives after a timer view is dismissed (e.g. a queued
//  WorkoutSessionEndedMessage) is never dropped.
//
//  Timer state itself travels through `TimerSyncTransport` (ADR-006); the only
//  legacy `WatchMessage` left is `WorkoutSessionEndedMessage`.
//

import Foundation
import SwiftData
import os

/// Links the Watch's HealthKit workout to the iPhone's `WorkoutLog` and publishes
/// the workout's HealthKit summary for the summary screen.
///
/// This is the *only* writer of `WatchConnectivityService.onMessageReceived`.
@Observable
final class PhoneMessageCoordinator {
    /// The most recent HealthKit summary from the Watch. The timer screen shows the
    /// one whose `correlationID` matches its workout. Assigning an equal message (a
    /// dual-delivery duplicate) is not a change, so observers see each summary once.
    private(set) var lastWorkoutSessionEnded: WorkoutSessionEndedMessage?

    /// Model context for WorkoutLog updates. Updating the log with the Watch's
    /// HealthKit UUID happens here — not in the view — so a message arriving
    /// after the runner view is gone still lands.
    var modelContext: ModelContext?

    /// - Parameter modelContext: Wired at construction (from `App.init`) so a `WorkoutSessionEndedMessage`
    ///   can link the Watch's HealthKit UUID even on a background WatchConnectivity launch, where no
    ///   scene appears and a view-driven `.onAppear` would never fire.
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        WatchConnectivityService.shared.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
        Logger.timerSync.info("PhoneMessageCoordinator initialized")
    }

    /// Routes an incoming message. Internal so tests can invoke it directly.
    @MainActor
    func handleMessage(_ message: WatchMessage) {
        guard let endedMessage = message as? WorkoutSessionEndedMessage else {
            Logger.timerSync.warning("Ignoring unexpected Watch message: \(message.messageType.rawValue)")
            return
        }
        // Attempt the UUID link on *every* delivery. The link is idempotent (no-op once set), so a
        // dual-delivery twin can still complete a link the first delivery couldn't (e.g. it arrived
        // before modelContext was wired).
        updateLogWithWatchUUID(endedMessage)
        if lastWorkoutSessionEnded != endedMessage {
            lastWorkoutSessionEnded = endedMessage
        }
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
