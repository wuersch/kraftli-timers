//
//  WatchCountdownCoordinator.swift
//  Kraftli Timers Watch App
//
//  Displays the pre-workout 3-2-1-GO countdown on Apple Watch.
//

import Foundation

/// Displays a 3-2-1-GO countdown toward a workout's shared start date.
///
/// Display only (ADR-006): the timer model already follows the workout's `TimerState`,
/// which starts the clock at `startDate` on both devices. Unlike the iOS coordinator,
/// this version plays no audio (unreliable when the wrist is down).
@Observable
@MainActor
final class WatchCountdownCoordinator {
    // MARK: - Public State

    /// Current countdown value: 3/2/1 = counting, 0 = "GO" display, nil = inactive.
    private(set) var countdownValue: Int? = nil

    /// Whether a countdown is currently in progress.
    private(set) var isCountingDown: Bool = false

    // MARK: - Private State

    private var countdownTask: Task<Void, Never>?

    // MARK: - Public Methods

    /// Counts down to `scheduledStartTime`, joining at whatever position matches the
    /// current time. Does nothing if that time has already passed.
    func startCountdown(scheduledStartTime: Date) {
        cancelCountdown()

        let timeUntilStart = scheduledStartTime.timeIntervalSince(Date())
        guard timeUntilStart > 0 else { return }

        isCountingDown = true

        countdownTask = Task { [weak self] in
            guard let self else { return }

            // Calculate which count to join at (ceiling of seconds remaining)
            var currentCount = min(3, Int(ceil(timeUntilStart)))

            // Display each count and wait
            while currentCount > 0 && !Task.isCancelled {
                self.countdownValue = currentCount

                // Wait until the next count
                let targetTime = scheduledStartTime.addingTimeInterval(-Double(currentCount - 1))
                let delay = targetTime.timeIntervalSince(Date())

                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }

                currentCount -= 1
            }

            guard !Task.isCancelled else { return }

            // Show "GO" (represented as 0) briefly; the workout clock is already running.
            self.countdownValue = 0
            try? await Task.sleep(for: .milliseconds(400))

            guard !Task.isCancelled else { return }
            self.countdownValue = nil
            self.isCountingDown = false
        }
    }

    /// Cancels any in-progress countdown.
    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
        isCountingDown = false
    }

    /// Hides the remaining countdown (tap on the countdown screen). The workout still
    /// starts at its shared start date, so a skip can't run the Watch ahead of the iPhone.
    func finishNow() {
        guard isCountingDown else { return }
        cancelCountdown()
    }
}
