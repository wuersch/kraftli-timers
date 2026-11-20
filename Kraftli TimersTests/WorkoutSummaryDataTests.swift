//
//  WorkoutSummaryDataTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct WorkoutSummaryDataTests {
    private func summary() -> WorkoutSummaryData {
        WorkoutSummaryData(
            exerciseName: "Pull-ups", timerKind: .amrap, duration: 600, reps: nil, rounds: 7, ownedByWatch: true
        )
    }

    @Test func merge_takesTheWatchsFigures() {
        var data = summary()
        data.merge(WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: UUID(), correlationID: UUID(),
            averageHeartRate: 140, maxHeartRate: 170, activeCalories: 120
        ))

        #expect(data.averageHeartRate == 140)
        #expect(data.maxHeartRate == 170)
        #expect(data.activeCalories == 120)
    }

    /// The Watch sends no figures when its session ends on dismiss: those already shown stay.
    @Test func merge_keepsFiguresTheMessageLacks() {
        var data = summary()
        data.merge(WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: UUID(), correlationID: UUID(),
            averageHeartRate: 140, maxHeartRate: 170, activeCalories: 120
        ))
        data.merge(WorkoutSessionEndedMessage(healthKitWorkoutUUID: nil, correlationID: UUID()))

        #expect(data.averageHeartRate == 140)
        #expect(data.maxHeartRate == 170)
        #expect(data.activeCalories == 120)
    }
}
