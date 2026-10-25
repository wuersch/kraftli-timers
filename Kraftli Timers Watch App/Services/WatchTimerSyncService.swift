//
//  WatchTimerSyncService.swift
//  Kraftli Timers Watch App
//
//  Sends the end-of-workout HealthKit summary from Watch to iPhone.
//  Timer state itself travels through `TimerSyncTransport` (ADR-006).
//

import Foundation
import os

// MARK: - Protocol

/// Sends the Watch's HealthKit results for an iPhone-started workout to the iPhone.
protocol WatchTimerSyncService {
    /// Sends a workout session ended message to iPhone with the HealthKit UUID and metrics.
    ///
    /// Uses dual delivery (`sendMessage` + `transferUserInfo`) to ensure the
    /// UUID reaches iPhone even if it's not immediately reachable.
    ///
    /// - Parameters:
    ///   - healthKitUUID: The UUID of the HKWorkout saved by Watch
    ///   - correlationID: The workout ID (the iPhone's `WorkoutLog.id`) for exact matching
    ///   - averageHeartRate: Average HR during the workout (BPM)
    ///   - maxHeartRate: Maximum HR during the workout (BPM)
    ///   - activeCalories: Active calories burned (kcal)
    ///   - completion: Called with the result of the immediate send attempt
    func sendWorkoutSessionEnded(
        healthKitUUID: UUID?,
        correlationID: UUID?,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        activeCalories: Double?,
        completion: ((Result<Void, Error>) -> Void)?
    )
}

// MARK: - Default Implementation

/// Default implementation using WatchConnectivityService.
final class DefaultWatchTimerSyncService: WatchTimerSyncService {
    private let connectivity: WatchConnectivityService

    init(connectivity: WatchConnectivityService = .shared) {
        self.connectivity = connectivity
    }

    func sendWorkoutSessionEnded(
        healthKitUUID: UUID?,
        correlationID: UUID?,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        activeCalories: Double?,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: healthKitUUID,
            correlationID: correlationID,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            activeCalories: activeCalories
        )
        // Dual delivery: transferUserInfo is reliable (queued by the system and
        // delivered even when iPhone is closed), while sendMessage provides
        // immediate delivery when iPhone is already reachable.
        // iPhone deduplicates messages that arrive via both paths.
        connectivity.transferUserInfo(message)
        connectivity.sendMessage(message, completion: completion)
        Logger.healthKit.info("Sent workoutSessionEnded (dual delivery), UUID: \(healthKitUUID?.uuidString ?? "none"), correlationID: \(correlationID?.uuidString ?? "none"), avgHR: \(averageHeartRate.map { String(format: "%.0f", $0) } ?? "none")")
    }
}

// MARK: - Silent Implementation

/// Silent implementation that does nothing. Useful for previews and tests.
final class SilentWatchTimerSyncService: WatchTimerSyncService {
    func sendWorkoutSessionEnded(
        healthKitUUID: UUID?,
        correlationID: UUID?,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        activeCalories: Double?,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op
    }
}
