//
//  WatchMessageCoordinatorTests.swift
//  Kraftli Timers Watch AppTests
//

import Combine
import Foundation
import Testing
@testable import Kraftli_Timers_Watch_App

struct WatchMessageCoordinatorTests {

    private func makeStart(
        correlationID: UUID? = UUID(),
        scheduledStartTime: Date? = Date(),
        totalDuration: TimeInterval = 600
    ) -> StartTimerMessage {
        StartTimerMessage(
            timerKind: .emom,
            totalDuration: totalDuration,
            intervalCount: 10,
            exerciseName: "Burpees",
            displayOnly: true,
            scheduledStartTime: scheduledStartTime,
            correlationID: correlationID
        )
    }

    // MARK: - Start handling

    @Test @MainActor func start_setsPendingStartTimer() {
        let coordinator = WatchMessageCoordinator()

        coordinator.handleMessage(makeStart())

        #expect(coordinator.pendingStartTimer != nil)
    }

    @Test @MainActor func duplicateStart_sameCorrelationID_handledOnce() {
        let coordinator = WatchMessageCoordinator()
        let message = makeStart()

        coordinator.handleMessage(message)
        coordinator.pendingStartTimer = nil  // UI consumed it

        // Same command arrives again (fast path + application context)
        coordinator.handleMessage(message)

        #expect(coordinator.pendingStartTimer == nil)
    }

    @Test @MainActor func startAfterStop_sameCorrelationID_isIgnored() {
        let coordinator = WatchMessageCoordinator()
        let correlationID = UUID()

        // Stop arrives first (no active timer → orphaned, but the ID is recorded)
        coordinator.handleMessage(StopTimerMessage(correlationID: correlationID))

        // A late start for the already-stopped timer must not resurrect it
        coordinator.handleMessage(makeStart(correlationID: correlationID))

        #expect(coordinator.pendingStartTimer == nil)
    }

    @Test @MainActor func expiredStart_isIgnored() {
        let coordinator = WatchMessageCoordinator()

        // Scheduled 700 s ago with a 600 s duration → workout already over
        coordinator.handleMessage(makeStart(
            scheduledStartTime: Date().addingTimeInterval(-700),
            totalDuration: 600
        ))

        #expect(coordinator.pendingStartTimer == nil)
    }

    @Test @MainActor func lateButLiveStart_isAccepted() {
        let coordinator = WatchMessageCoordinator()

        // Scheduled 300 s ago with a 600 s duration → workout still running
        coordinator.handleMessage(makeStart(
            scheduledStartTime: Date().addingTimeInterval(-300),
            totalDuration: 600
        ))

        #expect(coordinator.pendingStartTimer != nil)
    }

    // MARK: - Stop handling

    @Test @MainActor func twoDistinctStops_bothApply() {
        let coordinator = WatchMessageCoordinator()
        let syncService = DefaultWatchTimerSyncService()
        coordinator.activeSyncService = syncService

        var stopCount = 0
        let cancellable = syncService.timerControlReceived.sink { action in
            if action == .stop { stopCount += 1 }
        }
        defer { cancellable.cancel() }

        // First timer stopped
        let firstID = UUID()
        coordinator.activeCorrelationID = firstID
        coordinator.handleMessage(StopTimerMessage(correlationID: firstID))

        // Second timer starts and is stopped within the dedup window
        let secondID = UUID()
        coordinator.activeCorrelationID = secondID
        coordinator.handleMessage(StopTimerMessage(correlationID: secondID))

        #expect(stopCount == 2)
    }

    @Test @MainActor func duplicateStop_sameCorrelationID_appliesOnce() {
        let coordinator = WatchMessageCoordinator()
        let syncService = DefaultWatchTimerSyncService()
        coordinator.activeSyncService = syncService

        var stopCount = 0
        let cancellable = syncService.timerControlReceived.sink { action in
            if action == .stop { stopCount += 1 }
        }
        defer { cancellable.cancel() }

        let correlationID = UUID()
        coordinator.activeCorrelationID = correlationID
        let stop = StopTimerMessage(correlationID: correlationID)
        coordinator.handleMessage(stop)
        coordinator.handleMessage(stop)  // dual delivery duplicate

        #expect(stopCount == 1)
    }

    @Test @MainActor func stop_mismatchedCorrelationID_isIgnored() {
        let coordinator = WatchMessageCoordinator()
        let syncService = DefaultWatchTimerSyncService()
        coordinator.activeSyncService = syncService
        coordinator.activeCorrelationID = UUID()

        var stopCount = 0
        let cancellable = syncService.timerControlReceived.sink { action in
            if action == .stop { stopCount += 1 }
        }
        defer { cancellable.cancel() }

        // Stale stop from a previous timer must not kill the active one
        coordinator.handleMessage(StopTimerMessage(correlationID: UUID()))

        #expect(stopCount == 0)
    }
}
