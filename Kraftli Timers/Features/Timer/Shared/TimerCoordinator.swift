//
//  TimerCoordinator.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 25.12.2025.
//

import Foundation

/// Coordinates timer execution and pause/resume state management
/// Reduces duplication across different timer model implementations
///
/// `@MainActor`-isolated: the run-loop Timer/CADisplayLink it owns must be scheduled and
/// invalidated on the main thread, and an `isolated deinit` requires an actor-isolated type.
@MainActor
final class TimerCoordinator {
    // MARK: - Properties
    private let timerProvider: TimerProvider
    private var timer: Any?

    // MARK: - Initialization
    init(timerProvider: TimerProvider) {
        self.timerProvider = timerProvider
    }

    // MARK: - Public Methods

    /// Starts ticking: calls `updateBlock` on the main actor until `stop()`.
    ///
    /// The coordinator only drives re-rendering. What a tick shows comes from the
    /// `TimerState` the model renders (ADR-006), so no start date is kept here.
    func start(updateBlock: @escaping () -> Void) {
        timer = timerProvider.scheduleTimer(interval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                updateBlock()
            }
        }
    }

    /// Stops the timer and clears state
    func stop() {
        if let timer = timer {
            timerProvider.invalidateTimer(timer)
            self.timer = nil
        }
    }

    /// Returns whether the timer is currently running
    var isActive: Bool {
        timer != nil
    }

    // MARK: - Cleanup
    // `isolated deinit` runs cleanup on the coordinator's (main) actor, so invalidating the
    // run-loop Timer/CADisplayLink in `stop()` happens on the thread that scheduled it — honoring
    // the Timer API contract rather than tearing it down from whatever thread drops the last ref.
    isolated deinit {
        stop()
    }
}
