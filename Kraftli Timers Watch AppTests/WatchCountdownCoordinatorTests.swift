//
//  WatchCountdownCoordinatorTests.swift
//  Kraftli Timers Watch AppTests
//
//  Regression tests for the joined-countdown skip anchor (ADR-005, issue #44
//  finding 5). Tapping the countdown screen calls `finishNow()`. For an
//  iPhone-led ("joined") countdown the skip must start the Watch anchored to the
//  *shared* `scheduledStartTime`, not at local now — otherwise a tap before the
//  scheduled start runs the Watch ahead of the leader and ends the HK session
//  early. Natural completion keeps the `nil` anchor (start at local now), which
//  matches the iPhone's natural countdown path and stays in lockstep.
//
//  These cover the synchronous, deterministic paths (skip + already-past). The
//  natural-completion timing path is driven by Task.sleep and is left to manual
//  verification.
//

import Foundation
import Testing
@testable import Kraftli_Timers_Watch_App

struct WatchCountdownCoordinatorTests {

    /// Tap-to-skip during a joined countdown fires the completion with the shared
    /// scheduled start time, so the Watch anchors to the leader rather than to the
    /// (earlier) tap moment.
    @Test @MainActor func finishNow_whileCountingDown_passesScheduledAnchor() {
        let coordinator = WatchCountdownCoordinator()
        let scheduled = Date().addingTimeInterval(3)
        var capturedAnchors: [Date?] = []

        coordinator.startCountdown(scheduledStartTime: scheduled) { anchor in
            capturedAnchors.append(anchor)
        }
        #expect(coordinator.isCountingDown)

        coordinator.finishNow()

        #expect(capturedAnchors == [scheduled])
        #expect(!coordinator.isCountingDown)
    }

    /// `finishNow()` is a no-op when no countdown is in progress (guards against a
    /// stray tap firing a start with no stored completion).
    @Test @MainActor func finishNow_whenNotCountingDown_doesNothing() {
        let coordinator = WatchCountdownCoordinator()
        coordinator.finishNow()
        #expect(!coordinator.isCountingDown)
    }

    /// A scheduled time already in the past skips the countdown and completes
    /// immediately with a `nil` anchor (start at local now — the late-join case
    /// is handled by the caller, not by a future-dated anchor here).
    @Test @MainActor func startCountdown_pastScheduledTime_completesImmediatelyWithNilAnchor() {
        let coordinator = WatchCountdownCoordinator()
        var capturedAnchors: [Date?] = []

        coordinator.startCountdown(scheduledStartTime: Date().addingTimeInterval(-5)) { anchor in
            capturedAnchors.append(anchor)
        }

        #expect(capturedAnchors == [Date?.none])
        #expect(!coordinator.isCountingDown)
    }
}
