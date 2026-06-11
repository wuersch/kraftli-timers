//
//  WatchMessageTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct WatchMessageTests {

    // MARK: - StartTimerMessage.isExpired

    @Test func isExpired_noScheduledStartTime_neverExpires() {
        let message = StartTimerMessage(
            timerKind: .emom,
            totalDuration: 600,
            exerciseName: "Burpees",
            scheduledStartTime: nil
        )

        #expect(message.isExpired(asOf: Date.distantFuture) == false)
    }

    @Test func isExpired_workoutStillRunning_isFalse() {
        let scheduled = Date(timeIntervalSince1970: 1_000_000)
        let message = StartTimerMessage(
            timerKind: .amrap,
            totalDuration: 600,
            exerciseName: "Pull-ups",
            scheduledStartTime: scheduled
        )

        // Halfway through the workout
        #expect(message.isExpired(asOf: scheduled.addingTimeInterval(300)) == false)
    }

    @Test func isExpired_exactlyAtWorkoutEnd_isFalse() {
        let scheduled = Date(timeIntervalSince1970: 1_000_000)
        let message = StartTimerMessage(
            timerKind: .emom,
            totalDuration: 600,
            exerciseName: "Burpees",
            scheduledStartTime: scheduled
        )

        // Boundary: `now > scheduled + duration` is strict
        #expect(message.isExpired(asOf: scheduled.addingTimeInterval(600)) == false)
    }

    @Test func isExpired_pastWorkoutEnd_isTrue() {
        let scheduled = Date(timeIntervalSince1970: 1_000_000)
        let message = StartTimerMessage(
            timerKind: .emom,
            totalDuration: 600,
            exerciseName: "Burpees",
            scheduledStartTime: scheduled
        )

        #expect(message.isExpired(asOf: scheduled.addingTimeInterval(601)) == true)
    }

    // MARK: - WatchMessageCoder round-trip (application context payload format)

    @Test func coderRoundTrip_startTimerMessage_preservesAllFields() throws {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000.5)
        let correlationID = UUID()
        let original = StartTimerMessage(
            timerKind: .emom,
            totalDuration: 1200,
            intervalCount: 100,
            exerciseName: "6-Count Burpees",
            displayOnly: true,
            scheduledStartTime: scheduled,
            correlationID: correlationID
        )

        let encoded = try WatchMessageCoder.encode(original)
        let decoded = try WatchMessageCoder.decode(encoded)

        let roundTripped = try #require(decoded as? StartTimerMessage)
        #expect(roundTripped == original)
    }

    @Test func coderRoundTrip_stopTimerMessage_preservesCorrelationID() throws {
        let correlationID = UUID()
        let original = StopTimerMessage(correlationID: correlationID)

        let encoded = try WatchMessageCoder.encode(original)
        let decoded = try WatchMessageCoder.decode(encoded)

        let roundTripped = try #require(decoded as? StopTimerMessage)
        #expect(roundTripped == original)
    }

    @Test func coderRoundTrip_stopTimerMessage_nilCorrelationID() throws {
        let original = StopTimerMessage(correlationID: nil)

        let encoded = try WatchMessageCoder.encode(original)
        let decoded = try WatchMessageCoder.decode(encoded)

        let roundTripped = try #require(decoded as? StopTimerMessage)
        #expect(roundTripped == original)
    }
}
