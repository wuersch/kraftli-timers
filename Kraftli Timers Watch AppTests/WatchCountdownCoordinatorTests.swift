//
//  WatchCountdownCoordinatorTests.swift
//  Kraftli Timers Watch AppTests
//
//  The Watch countdown only displays 3-2-1-GO toward the shared start date (ADR-006);
//  the timer itself follows the workout's state. These cover the synchronous paths.
//  The timing path is driven by Task.sleep and is left to manual verification.
//

import Foundation
import Testing
@testable import Kraftli_Timers_Watch_App

struct WatchCountdownCoordinatorTests {

    @Test @MainActor func startCountdown_futureStart_countsDown() {
        let coordinator = WatchCountdownCoordinator()

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(3))

        #expect(coordinator.isCountingDown)
        coordinator.cancelCountdown()
    }

    /// Tap-to-skip hides the countdown; the workout still starts at its shared start date.
    @Test @MainActor func finishNow_whileCountingDown_hidesCountdown() {
        let coordinator = WatchCountdownCoordinator()
        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(3))

        coordinator.finishNow()

        #expect(!coordinator.isCountingDown)
        #expect(coordinator.countdownValue == nil)
    }

    @Test @MainActor func finishNow_whenNotCountingDown_doesNothing() {
        let coordinator = WatchCountdownCoordinator()
        coordinator.finishNow()
        #expect(!coordinator.isCountingDown)
    }

    /// A start date already in the past (e.g. a late join) shows no countdown at all.
    @Test @MainActor func startCountdown_pastStart_showsNothing() {
        let coordinator = WatchCountdownCoordinator()

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(-5))

        #expect(!coordinator.isCountingDown)
    }
}
