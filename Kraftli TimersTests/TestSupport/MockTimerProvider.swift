//
//  MockTimerProvider.swift
//  Kraftli TimersTests
//

import Foundation
@testable import Kraftli_Timers

/// A mock timer provider for unit tests that doesn't create real timers.
/// This eliminates MainActor contention and avoids resource accumulation.
final class MockTimerProvider: TimerProvider {
    var scheduleTimerCalled = false
    var invalidateTimerCalled = false
    private var tickHandler: ((Any) -> Void)?

    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping (Any) -> Void) -> Any {
        scheduleTimerCalled = true
        tickHandler = block
        // Return a dummy timer token
        return "MockTimer"
    }

    func invalidateTimer(_ timer: Any) {
        invalidateTimerCalled = true
        tickHandler = nil
    }

    /// Manually trigger a tick for testing timer logic
    func simulateTick() {
        tickHandler?("MockTimer")
    }
}
