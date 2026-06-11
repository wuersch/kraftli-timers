//
//  WatchMessage.swift
//  Kraftli Timers
//
//  Defines the message protocol for iPhone ↔ Watch communication.
//  Extensible for future message types (HealthKit, telemetry, etc.)
//

import Foundation

// MARK: - Message Type

/// Identifies the type of message being sent between devices.
/// Add new cases here for future features (HealthKit workout sessions, heart rate requests, etc.)
enum WatchMessageType: String, Codable {
    case startTimer
    case timerControl
    case stopTimer
    case workoutSessionEnded
    case timerStartedOnWatch
}

// MARK: - Timer Control Action

/// Actions that can be performed on a running timer.
enum TimerControlAction: String, Codable {
    case play
    case pause
    case stop
    case incrementRound  // AMRAP only: sync round count between devices
}

// MARK: - WatchMessage Protocol

/// Protocol for all messages sent between iPhone and Watch.
/// Each message type should be Codable for serialization over WatchConnectivity.
protocol WatchMessage: Codable {
    var messageType: WatchMessageType { get }
}

// MARK: - StartTimerMessage

/// Message sent from iPhone to Watch to start a timer.
///
/// When received, the Watch should:
/// 1. Present the appropriate timer view (EMOM or AMRAP)
/// 2. If `scheduledStartTime` is set, join the countdown in progress
/// 3. Start the timer at the scheduled time
/// 4. Run in display-only mode (skip workout logging since iPhone logs it)
struct StartTimerMessage: WatchMessage, Equatable {
    var messageType: WatchMessageType { .startTimer }

    let timerKindRaw: String
    let totalDuration: TimeInterval
    let intervalCount: Int?  // Only set for EMOM (number of intervals / reps)
    let exerciseName: String

    /// When true, watch should not log the workout (iPhone is the source of truth).
    let displayOnly: Bool

    /// Absolute time when the timer should start (after countdown completes).
    /// Watch uses this to join countdown in progress and synchronize timer start.
    let scheduledStartTime: Date?

    /// ID of the iPhone's WorkoutLog so Watch can echo it back in
    /// `WorkoutSessionEndedMessage.correlationID` for exact UUID matching.
    let correlationID: UUID?

    /// Convenience accessor for the timer kind enum.
    var timerKind: TimerKind {
        TimerKind(rawValue: timerKindRaw) ?? .emom
    }

    init(
        timerKind: TimerKind,
        totalDuration: TimeInterval,
        intervalCount: Int? = nil,
        exerciseName: String,
        displayOnly: Bool = true,
        scheduledStartTime: Date? = nil,
        correlationID: UUID? = nil
    ) {
        self.timerKindRaw = timerKind.rawValue
        self.totalDuration = totalDuration
        self.intervalCount = intervalCount
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.scheduledStartTime = scheduledStartTime
        self.correlationID = correlationID
    }

    // Custom Codable to exclude computed messageType
    private enum CodingKeys: String, CodingKey {
        case timerKindRaw, totalDuration, intervalCount, exerciseName, displayOnly, scheduledStartTime, correlationID
    }

    /// True when the workout this message describes is already over —
    /// the scheduled start plus the full duration lies in the past.
    /// Messages without a scheduled start never expire.
    func isExpired(asOf now: Date = Date()) -> Bool {
        guard let scheduledStartTime else { return false }
        return now > scheduledStartTime.addingTimeInterval(totalDuration)
    }
}

// MARK: - TimerControlMessage

/// Message sent between devices to control a mirrored timer.
///
/// Used for play/pause/stop synchronization when a timer is mirrored
/// from iPhone to Watch. Either device can send this message.
struct TimerControlMessage: WatchMessage, Equatable {
    var messageType: WatchMessageType { .timerControl }

    let action: TimerControlAction

    init(action: TimerControlAction) {
        self.action = action
    }

    // Custom Codable to exclude computed messageType
    private enum CodingKeys: String, CodingKey {
        case action
    }
}

// MARK: - StopTimerMessage

/// Reliable stop message sent from iPhone to Watch via `transferUserInfo`.
///
/// Unlike `TimerControlMessage(.stop)` which uses `sendMessage` (requires reachability),
/// this is queued by the system and delivered even when the Watch is unreachable.
/// Uses a correlation ID to prevent stale stops from killing new timers — if the ID
/// doesn't match the active timer, the stop is ignored.
struct StopTimerMessage: WatchMessage, Equatable {
    var messageType: WatchMessageType { .stopTimer }

    /// Matches against the active timer's correlation ID.
    /// If nil or matching → apply the stop. If mismatched → ignore (stale stop).
    let correlationID: UUID?

    init(correlationID: UUID? = nil) {
        self.correlationID = correlationID
    }

    // Custom Codable to exclude computed messageType
    private enum CodingKeys: String, CodingKey {
        case correlationID
    }
}

// MARK: - WorkoutSessionEndedMessage

/// Message sent from Watch to iPhone when an HKWorkoutSession ends.
///
/// Contains the HealthKit workout UUID so iPhone can correlate its
/// SwiftData WorkoutLog with the Watch's HealthKit workout, plus
/// workout metrics (heart rate, calories) for the summary screen.
struct WorkoutSessionEndedMessage: WatchMessage, Equatable {
    var messageType: WatchMessageType { .workoutSessionEnded }

    /// UUID of the HKWorkout saved by Watch, if available.
    let healthKitWorkoutUUID: UUID?

    /// Correlation ID echoed from `StartTimerMessage` so iPhone can match
    /// the UUID to the exact WorkoutLog, rather than using a fragile "latest" heuristic.
    let correlationID: UUID?

    // MARK: - Workout Metrics

    /// Average heart rate during the workout (beats per minute).
    let averageHeartRate: Double?

    /// Maximum heart rate during the workout (beats per minute).
    let maxHeartRate: Double?

    /// Active calories burned during the workout (kilocalories).
    let activeCalories: Double?

    init(
        healthKitWorkoutUUID: UUID?,
        correlationID: UUID? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        activeCalories: Double? = nil
    ) {
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.correlationID = correlationID
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeCalories = activeCalories
    }

    // Custom Codable to exclude computed messageType
    private enum CodingKeys: String, CodingKey {
        case healthKitWorkoutUUID
        case correlationID
        case averageHeartRate
        case maxHeartRate
        case activeCalories
    }
}

// MARK: - TimerStartedOnWatchMessage

/// Message sent from Watch to iPhone when a timer starts on Watch.
///
/// Allows iPhone to display a mirrored timer view if the app is running.
/// If iPhone isn't running, the Watch workout proceeds independently.
struct TimerStartedOnWatchMessage: WatchMessage, Equatable {
    var messageType: WatchMessageType { .timerStartedOnWatch }

    let timerKindRaw: String
    let totalDuration: TimeInterval
    let intervalCount: Int?
    let exerciseName: String

    var timerKind: TimerKind {
        TimerKind(rawValue: timerKindRaw) ?? .emom
    }

    init(
        timerKind: TimerKind,
        totalDuration: TimeInterval,
        intervalCount: Int? = nil,
        exerciseName: String
    ) {
        self.timerKindRaw = timerKind.rawValue
        self.totalDuration = totalDuration
        self.intervalCount = intervalCount
        self.exerciseName = exerciseName
    }

    // Custom Codable to exclude computed messageType
    private enum CodingKeys: String, CodingKey {
        case timerKindRaw, totalDuration, intervalCount, exerciseName
    }
}

// MARK: - Message Encoding/Decoding

/// Encodes and decodes WatchMessage types for WatchConnectivity transport.
///
/// WatchConnectivity requires [String: Any] dictionaries, so we wrap
/// Codable messages in a dictionary with a type discriminator.
enum WatchMessageCoder {

    private static let typeKey = "messageType"
    private static let payloadKey = "payload"

    /// Encodes a WatchMessage to a dictionary for WatchConnectivity transport.
    static func encode(_ message: WatchMessage) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WatchMessageError.encodingFailed
        }

        return [
            typeKey: message.messageType.rawValue,
            payloadKey: payload
        ]
    }

    /// Decodes a WatchMessage from a WatchConnectivity dictionary.
    static func decode(_ dictionary: [String: Any]) throws -> WatchMessage {
        guard let typeRaw = dictionary[typeKey] as? String,
              let messageType = WatchMessageType(rawValue: typeRaw),
              let payload = dictionary[payloadKey] as? [String: Any] else {
            throw WatchMessageError.invalidFormat
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()

        switch messageType {
        case .startTimer:
            return try decoder.decode(StartTimerMessage.self, from: data)
        case .timerControl:
            return try decoder.decode(TimerControlMessage.self, from: data)
        case .stopTimer:
            return try decoder.decode(StopTimerMessage.self, from: data)
        case .workoutSessionEnded:
            return try decoder.decode(WorkoutSessionEndedMessage.self, from: data)
        case .timerStartedOnWatch:
            return try decoder.decode(TimerStartedOnWatchMessage.self, from: data)
        }
    }
}

// MARK: - Errors

enum WatchMessageError: Error, LocalizedError {
    case encodingFailed
    case invalidFormat
    case unknownMessageType

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode message for WatchConnectivity"
        case .invalidFormat:
            return "Received message has invalid format"
        case .unknownMessageType:
            return "Received unknown message type"
        }
    }
}
