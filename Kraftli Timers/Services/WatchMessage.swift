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
    // Future: case startWorkoutSession, case requestHeartRate
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
/// 2. Start the timer immediately
/// 3. Run in display-only mode (skip workout logging since iPhone logs it)
struct StartTimerMessage: WatchMessage, Equatable {
    var messageType: WatchMessageType { .startTimer }

    let timerKindRaw: String
    let totalDuration: TimeInterval
    let intervalDuration: TimeInterval?  // Only set for EMOM
    let exerciseName: String

    /// When true, watch should not log the workout (iPhone is the source of truth).
    let displayOnly: Bool

    /// Convenience accessor for the timer kind enum.
    var timerKind: TimerKind {
        TimerKind(rawValue: timerKindRaw) ?? .emom
    }

    init(
        timerKind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval? = nil,
        exerciseName: String,
        displayOnly: Bool = true
    ) {
        self.timerKindRaw = timerKind.rawValue
        self.totalDuration = totalDuration
        self.intervalDuration = intervalDuration
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
    }

    // Custom Codable to exclude computed messageType
    private enum CodingKeys: String, CodingKey {
        case timerKindRaw, totalDuration, intervalDuration, exerciseName, displayOnly
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
