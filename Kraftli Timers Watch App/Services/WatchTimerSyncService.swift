//
//  WatchTimerSyncService.swift
//  Kraftli Timers Watch App
//
//  Service for sending timer control messages from Watch to iPhone.
//  Used when a mirrored timer (started from iPhone) is controlled on Watch.
//

import Foundation
import Combine
import os

// MARK: - Protocol

/// Service for sending timer control messages from Watch to iPhone.
///
/// Use this protocol to send play/pause/stop commands to iPhone
/// when controlling a mirrored timer on Watch.
protocol WatchTimerSyncService {
    /// Whether the iPhone is currently reachable for immediate communication.
    var isPhoneReachable: Bool { get }

    /// Sends a timer control command to iPhone.
    ///
    /// - Parameters:
    ///   - action: The control action (play, pause, stop)
    ///   - completion: Called with the result of the send operation
    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)?
    )

    /// Sends a workout session ended message to iPhone with the HealthKit UUID and metrics.
    ///
    /// Uses dual delivery (`sendMessage` + `transferUserInfo`) to ensure the
    /// UUID reaches iPhone even if it's not immediately reachable.
    ///
    /// - Parameters:
    ///   - healthKitUUID: The UUID of the HKWorkout saved by Watch
    ///   - correlationID: The WorkoutLog ID for exact matching on iPhone
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

    /// Sends a notification to iPhone that a timer started on Watch (Scenario D).
    ///
    /// This is best-effort — the Watch workout proceeds regardless of delivery.
    /// Uses `sendMessage` only (no queued delivery needed).
    ///
    /// - Parameters:
    ///   - kind: The type of timer (EMOM or AMRAP)
    ///   - totalDuration: Total workout duration in seconds
    ///   - intervalCount: Number of intervals/reps for EMOM (nil for AMRAP)
    ///   - exerciseName: Name of the exercise
    ///   - completion: Called with the result of the send operation
    func sendTimerStartedOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalCount: Int?,
        exerciseName: String,
        completion: ((Result<Void, Error>) -> Void)?
    )

    /// Publisher that emits when a control message is received from iPhone.
    var timerControlReceived: AnyPublisher<TimerControlAction, Never> { get }
}

// MARK: - Default Implementation

/// Default implementation using WatchConnectivityService.
///
/// Note: This service no longer sets up its own message handler.
/// The WatchMessageCoordinator handles message routing and forwards
/// control messages via `handleControlMessage(_:)`.
final class DefaultWatchTimerSyncService: WatchTimerSyncService {
    private let connectivity: WatchConnectivityService
    private let timerControlSubject = PassthroughSubject<TimerControlAction, Never>()

    init(connectivity: WatchConnectivityService = .shared) {
        self.connectivity = connectivity
    }

    var isPhoneReachable: Bool {
        connectivity.isReachable
    }

    var timerControlReceived: AnyPublisher<TimerControlAction, Never> {
        timerControlSubject.eraseToAnyPublisher()
    }

    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = TimerControlMessage(action: action)
        connectivity.sendMessage(message, completion: completion)
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

    func sendTimerStartedOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalCount: Int?,
        exerciseName: String,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = TimerStartedOnWatchMessage(
            timerKind: kind,
            totalDuration: totalDuration,
            intervalCount: intervalCount,
            exerciseName: exerciseName
        )
        // Best-effort: sendMessage only (Watch workout proceeds regardless)
        connectivity.sendMessage(message, completion: completion)
    }

    // MARK: - Internal (for WatchMessageCoordinator)

    /// Handles a control message forwarded from the coordinator.
    func handleControlMessage(_ message: TimerControlMessage) {
        timerControlSubject.send(message.action)
    }
}

// MARK: - Silent Implementation

/// Silent implementation that does nothing. Useful for standalone Watch timers.
final class SilentWatchTimerSyncService: WatchTimerSyncService {
    var isPhoneReachable: Bool { false }

    var timerControlReceived: AnyPublisher<TimerControlAction, Never> {
        Empty().eraseToAnyPublisher()
    }

    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op for standalone timers
    }

    func sendWorkoutSessionEnded(
        healthKitUUID: UUID?,
        correlationID: UUID?,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        activeCalories: Double?,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op for standalone timers
    }

    func sendTimerStartedOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalCount: Int?,
        exerciseName: String,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op for standalone timers
    }
}
