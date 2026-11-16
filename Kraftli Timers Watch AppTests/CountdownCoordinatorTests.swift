//
//  CountdownCoordinatorTests.swift
//  Kraftli Timers Watch AppTests
//
//  The countdown (shared with the iPhone) only displays 3-2-1-GO toward the shared start date (ADR-006);
//  the timer itself follows the workout's state. These cover the synchronous paths.
//  The timing path is driven by Task.sleep and is left to manual verification.
//

import Foundation
import Testing
@testable import Kraftli_Timers_Watch_App

struct CountdownCoordinatorTests {

    @Test @MainActor func startCountdown_futureStart_countsDown() {
        let coordinator = CountdownCoordinator()

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(3))

        #expect(coordinator.isCountingDown)
        coordinator.cancelCountdown()
    }

    /// Tap-to-skip hides the countdown; the workout still starts at its shared start date.
    @Test @MainActor func finishNow_whileCountingDown_hidesCountdown() {
        let coordinator = CountdownCoordinator()
        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(3))

        coordinator.finishNow()

        #expect(!coordinator.isCountingDown)
        #expect(coordinator.countdownValue == nil)
    }

    @Test @MainActor func finishNow_whenNotCountingDown_doesNothing() {
        let coordinator = CountdownCoordinator()
        coordinator.finishNow()
        #expect(!coordinator.isCountingDown)
    }

    /// A start date already in the past (e.g. a late join) shows no countdown at all.
    @Test @MainActor func startCountdown_pastStart_showsNothing() {
        let coordinator = CountdownCoordinator()

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(-5))

        #expect(!coordinator.isCountingDown)
    }

    /// The iPhone relies on the completion to start its hint timer, also on a late join.
    @Test @MainActor func startCountdown_pastStart_completesRightAway() {
        let coordinator = CountdownCoordinator()
        var completed = false

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(-5)) {
            completed = true
        }

        #expect(completed)
    }

    /// Each displayed count is announced, so the iPhone can beep on it.
    @Test @MainActor func startCountdown_announcesTheFirstCount() async {
        var counts = 0
        let coordinator = CountdownCoordinator(onCount: { counts += 1 })

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(3))
        await Task.yield()

        #expect(counts == 1)
        #expect(coordinator.countdownValue == 3)
        coordinator.cancelCountdown()
    }
}
