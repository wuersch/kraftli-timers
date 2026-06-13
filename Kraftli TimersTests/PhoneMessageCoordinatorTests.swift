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

    // MARK: - Inbound StopTimerMessage (Watch→iPhone reliable stop, issue #45)

    /// A stop whose correlation ID matches the active timer is forwarded as `.stop`,
    /// so the runner dismisses without logging a cancelled workout as completed.
    @Test @MainActor func stop_matchingCorrelationID_forwardsStop() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService
        let correlationID = UUID()
        coordinator.activeCorrelationID = correlationID

        var receivedActions: [TimerControlAction] = []
        let cancellable = syncService.timerControlReceived.sink { receivedActions.append($0) }
        defer { cancellable.cancel() }

        coordinator.handleMessage(StopTimerMessage(correlationID: correlationID))

        #expect(receivedActions == [.stop])
    }

    /// A stop with no correlation ID applies to whatever timer is active.
    @Test @MainActor func stop_nilCorrelationID_forwardsStop() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService
        coordinator.activeCorrelationID = UUID()

        var receivedActions: [TimerControlAction] = []
        let cancellable = syncService.timerControlReceived.sink { receivedActions.append($0) }
        defer { cancellable.cancel() }

        coordinator.handleMessage(StopTimerMessage(correlationID: nil))

        #expect(receivedActions == [.stop])
    }

    /// A stale stop for a *different* workout must not kill the active timer.
    @Test @MainActor func stop_mismatchedCorrelationID_ignored() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService
        coordinator.activeCorrelationID = UUID()

        var receivedActions: [TimerControlAction] = []
        let cancellable = syncService.timerControlReceived.sink { receivedActions.append($0) }
        defer { cancellable.cancel() }

        coordinator.handleMessage(StopTimerMessage(correlationID: UUID()))  // different ID

        #expect(receivedActions.isEmpty)
    }

    /// Dual delivery (transferUserInfo + sendMessage) of the same stop forwards once.
    @Test @MainActor func stop_duplicateWithinWindow_forwardedOnce() {
        let coordinator = PhoneMessageCoordinator()
        let syncService = DefaultTimerSyncService()
        coordinator.activeSyncService = syncService
        let correlationID = UUID()
        coordinator.activeCorrelationID = correlationID

        var receivedActions: [TimerControlAction] = []
        let cancellable = syncService.timerControlReceived.sink { receivedActions.append($0) }
        defer { cancellable.cancel() }

        let message = StopTimerMessage(correlationID: correlationID)
        coordinator.handleMessage(message)
        coordinator.handleMessage(message)  // dual delivery duplicate

        #expect(receivedActions == [.stop])
    }

    /// A stop arriving with no active timer view is a no-op (the iPhone owns no HK
    /// session in the iPhone-led case) and must not crash.
    @Test @MainActor func stop_withNoActiveSyncService_doesNotCrash() {
        let coordinator = PhoneMessageCoordinator()
        coordinator.handleMessage(StopTimerMessage(correlationID: UUID()))
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
        let schema = Schema([WorkoutLog.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
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
