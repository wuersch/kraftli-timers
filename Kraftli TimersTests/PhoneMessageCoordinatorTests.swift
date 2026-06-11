//
//  PhoneMessageCoordinatorTests.swift
//  Kraftli TimersTests
//

import Combine
import Foundation
import SwiftData
import Testing
@testable import Kraftli_Timers

struct PhoneMessageCoordinatorTests {

    // MARK: - Routing

    @Test @MainActor func controlMessage_forwardsToActiveSyncService() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService

        var receivedActions: [TimerControlAction] = []
        let cancellable = syncService.timerControlReceived.sink { receivedActions.append($0) }
        defer { cancellable.cancel() }

        coordinator.handleMessage(TimerControlMessage(action: .pause))

        #expect(receivedActions == [.pause])
    }

    @Test @MainActor func message_withNoActiveSyncService_doesNotCrash() {
        let coordinator = PhoneMessageCoordinator()

        coordinator.handleMessage(TimerControlMessage(action: .stop))
        // Reaching this point without a crash is the assertion.
    }

    // MARK: - WorkoutSessionEnded dedup

    @Test @MainActor func duplicateSessionEnded_forwardedOnce() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService

        var receivedCount = 0
        let cancellable = syncService.workoutSessionEndedReceived.sink { _ in receivedCount += 1 }
        defer { cancellable.cancel() }

        let message = WorkoutSessionEndedMessage(
            healthKitWorkoutUUID: UUID(),
            correlationID: UUID(),
            averageHeartRate: 140,
            maxHeartRate: 170,
            activeCalories: 120
        )
        coordinator.handleMessage(message)
        coordinator.handleMessage(message)  // dual delivery duplicate

        #expect(receivedCount == 1)
    }

    @Test @MainActor func distinctSessionEnded_bothForwarded() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService

        var receivedCount = 0
        let cancellable = syncService.workoutSessionEndedReceived.sink { _ in receivedCount += 1 }
        defer { cancellable.cancel() }

        coordinator.handleMessage(WorkoutSessionEndedMessage(healthKitWorkoutUUID: UUID(), correlationID: UUID()))
        coordinator.handleMessage(WorkoutSessionEndedMessage(healthKitWorkoutUUID: UUID(), correlationID: UUID()))

        #expect(receivedCount == 2)
    }

    // MARK: - WorkoutLog HealthKit-UUID update (works without a live timer view)

    @Test @MainActor func sessionEnded_updatesLogByCorrelationID() throws {
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
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
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
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
}
