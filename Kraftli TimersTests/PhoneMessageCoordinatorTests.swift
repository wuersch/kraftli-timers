//
//  PhoneMessageCoordinatorTests.swift
//  Kraftli TimersTests
//

import Foundation
import SwiftData
import Testing
@testable import Kraftli_Timers

struct PhoneMessageCoordinatorTests {

    // MARK: - Publishing the HealthKit summary

    @Test @MainActor func sessionEnded_isPublishedForTheSummary() {
        let coordinator = PhoneMessageCoordinator()
        let message = WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: UUID(),
            correlationID: UUID(),
            averageHeartRate: 140,
            maxHeartRate: 170,
            activeCalories: 120
        )

        coordinator.handleMessage(message)
        coordinator.handleMessage(message)  // dual-delivery duplicate: no change

        #expect(coordinator.lastWorkoutSessionEnded == message)
    }

    @Test @MainActor func distinctSessionEnded_latestIsPublished() {
        let coordinator = PhoneMessageCoordinator()
        let second = WorkoutSessionEndedMessage(healthKitWorkoutUUID: UUID(), correlationID: UUID())

        coordinator.handleMessage(WorkoutSessionEndedMessage(healthKitWorkoutUUID: UUID(), correlationID: UUID()))
        coordinator.handleMessage(second)

        #expect(coordinator.lastWorkoutSessionEnded == second)
    }

    // MARK: - WorkoutLog HealthKit-UUID update (works without a live timer view)

    @Test @MainActor func sessionEnded_updatesLogByCorrelationID() throws {
        let container = try makeInMemoryContainer(for: WorkoutLog.self)
        let context = container.mainContext

        let correlationID = UUID()
        let log = WorkoutLog(
            id: correlationID,
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )
        context.insert(log)
        try context.save()

        let coordinator = PhoneMessageCoordinator()
        coordinator.modelContext = context

        let watchUUID = UUID()
        coordinator.handleMessage(WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: watchUUID,
            correlationID: correlationID
        ))

        #expect(log.healthKitWorkoutUUID == watchUUID)
    }

    @Test @MainActor func sessionEnded_mismatchedCorrelationID_leavesLogUntouched() throws {
        let container = try makeInMemoryContainer(for: WorkoutLog.self)
        let context = container.mainContext

        let log = WorkoutLog(
            id: UUID(),
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )
        context.insert(log)
        try context.save()

        let coordinator = PhoneMessageCoordinator()
        coordinator.modelContext = context

        coordinator.handleMessage(WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: UUID(),
            correlationID: UUID()  // doesn't match any log
        ))

        #expect(log.healthKitWorkoutUUID == nil)
    }

    /// Issue #48 / finding 10: if the first (dual-delivery) twin arrives before `modelContext` is
    /// wired, the UUID can't link yet. The twin within the dedup window must still complete the
    /// link — pre-fix it was dropped as a "duplicate" because dedup was committed before the apply.
    @Test @MainActor func sessionEnded_uuidLinkedByTwin_afterContextWired() throws {
        let coordinator = PhoneMessageCoordinator()  // modelContext nil (background-launch ordering)
        let correlationID = UUID()
        let watchUUID = UUID()
        let message = WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: watchUUID,
            correlationID: correlationID
        )

        // Twin 1: arrives before the context exists → can't link yet.
        coordinator.handleMessage(message)

        // Context is now wired with the matching log (no UUID yet).
        let container = try makeInMemoryContainer(for: WorkoutLog.self)
        let context = container.mainContext
        let log = WorkoutLog(
            id: correlationID,
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )
        context.insert(log)
        try context.save()
        coordinator.modelContext = context

        // Twin 2: same message within the dedup window — must still link, not be dropped.
        coordinator.handleMessage(message)

        #expect(log.healthKitWorkoutUUID == watchUUID)
    }
}
