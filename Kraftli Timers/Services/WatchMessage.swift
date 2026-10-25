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
///
/// Timer state and control travel as `TimerSyncPayload` (ADR-006). The only message left
/// on this path is the Watch's end-of-workout HealthKit summary.
enum WatchMessageType: String, Codable {
    case workoutSessionEnded
}

// MARK: - WatchMessage Protocol

/// Protocol for all messages sent between iPhone and Watch.
/// Each message type should be Codable for serialization over WatchConnectivity.
protocol WatchMessage: Codable {
    var messageType: WatchMessageType { get }
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

    /// The workout ID (the iPhone's `WorkoutLog.id`) so iPhone can match the UUID
    /// to the exact WorkoutLog, rather than using a fragile "latest" heuristic.
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
        case .workoutSessionEnded:
            return try decoder.decode(WorkoutSessionEndedMessage.self, from: data)
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
