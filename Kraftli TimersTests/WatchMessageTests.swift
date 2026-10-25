//
//  WatchMessageTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct WatchMessageTests {

    // MARK: - WatchMessageCoder

    @Test func coderRoundTrip_workoutSessionEnded_preservesAllFields() throws {
        let original = WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: UUID(),
            correlationID: UUID(),
            averageHeartRate: 142,
            maxHeartRate: 171,
            activeCalories: 118
        )

        let decoded = try WatchMessageCoder.decode(WatchMessageCoder.encode(original))

        #expect(decoded as? WorkoutSessionEndedMessage == original)
    }

    @Test func coderRoundTrip_workoutSessionEnded_nilFields() throws {
        let original = WorkoutSessionEndedMessage(healthKitWorkoutUUID: nil)

        let decoded = try WatchMessageCoder.decode(WatchMessageCoder.encode(original))

        #expect(decoded as? WorkoutSessionEndedMessage == original)
    }

    /// A message type from an older app version (e.g. the retired `startTimer`) fails to decode
    /// instead of being misread.
    @Test func decode_unknownMessageType_throws() {
        let dictionary: [String: Any] = ["messageType": "startTimer", "payload": [String: Any]()]

        #expect(throws: WatchMessageError.self) {
            try WatchMessageCoder.decode(dictionary)
        }
    }
}
