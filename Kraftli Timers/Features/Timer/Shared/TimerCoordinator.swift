//
//  TimerCoordinator.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 25.12.2025.
//

import Foundation

/// Coordinates timer execution and pause/resume state management
/// Reduces duplication across different timer model implementations
final class TimerCoordinator {
    // MARK: - Properties
    private let timerProvider: TimerProvider
    private var timer: Any?
    private var startDate: Date?

    // MARK: - Initialization
    init(timerProvider: TimerProvider = DisplayLinkTimerProvider()) {
        self.timerProvider = timerProvider
    }

    // MARK: - Public Methods

    /// Starts or resumes the timer
    /// - Parameters:
    ///   - pausedTime: Optional time remaining when paused, used to resume from correct point
    ///   - totalDuration: Total duration of the timer
    ///   - updateBlock: Closure called on each timer tick
    /// - Returns: The start date used for time calculations
    @MainActor
    func start(
        pausedTime: TimeInterval?,
        totalDuration: TimeInterval,
        updateBlock: @escaping () -> Void
    ) -> Date {
        let now = Date()

        // Calculate start date based on whether we're resuming or starting fresh
        if let pausedTime = pausedTime {
            startDate = now.addingTimeInterval(-totalDuration + pausedTime)
        } else {
            startDate = now
        }

        // Schedule timer with update block
        timer = timerProvider.scheduleTimer(interval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                updateBlock()
            }
        }

        return startDate!
    }

    /// Stops the timer and clears state
    func stop() {
        if let timer = timer {
            timerProvider.invalidateTimer(timer)
            self.timer = nil
        }
        startDate = nil
    }

    /// Returns whether the timer is currently running
    var isActive: Bool {
        timer != nil
    }

    // MARK: - Cleanup
    deinit {
        stop()
    }
}
