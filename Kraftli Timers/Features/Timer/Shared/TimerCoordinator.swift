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
    /// Wall-clock source. Injectable so tests can drive time deterministically.
    private let now: () -> Date
    private var timer: Any?
    private var startDate: Date?

    // MARK: - Initialization
    init(timerProvider: TimerProvider, now: @escaping () -> Date = { Date() }) {
        self.timerProvider = timerProvider
        self.now = now
    }

    // MARK: - Public Methods

    /// Starts or resumes the timer from a relative paused time.
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
        // Derive the absolute anchor from the paused remaining (or "now" for a fresh start),
        // then defer to the explicit-anchor path so both entry points share one tick setup.
        let anchor = pausedTime.map { now().addingTimeInterval(-totalDuration + $0) } ?? now()
        return start(startDate: anchor, updateBlock: updateBlock)
    }

    /// Starts or resumes the timer anchored to an explicit absolute `startDate`.
    ///
    /// The anchor is adopted **verbatim** — no recomputation from the local clock. This is
    /// what lets two devices agree on the same anchor: the caller hands in a shared, canonical
    /// start date (derived from HealthKit's transition `date`) rather than each device's `now()`.
    @MainActor
    @discardableResult
    func start(
        startDate: Date,
        updateBlock: @escaping () -> Void
    ) -> Date {
        self.startDate = startDate

        // Schedule timer with update block
        timer = timerProvider.scheduleTimer(interval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                updateBlock()
            }
        }

        return startDate
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
