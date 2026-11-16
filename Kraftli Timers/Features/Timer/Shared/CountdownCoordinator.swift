//
//  CountdownCoordinator.swift
//  Kraftli Timers
//
//  Displays the pre-workout countdown (3, 2, 1, GO). Shared by the iPhone and
//  Watch targets.
//

import Foundation

/// Displays a 3-2-1-GO countdown toward a workout's shared start date.
///
/// Display only (ADR-006): the timer model already follows the workout's `TimerState`,
/// which starts the clock at `startDate` on both devices. The countdown gives the
/// athlete time to get into position and joins at whatever count matches the current
/// time, so both devices show the same number.
///
/// ## Usage
/// ```swift
/// @State private var countdown = CountdownCoordinator(onCount: { playBeep() })
///
/// countdown.startCountdown(scheduledStartTime: state.startDate) {
///     // The countdown is over: the timer model already follows the state.
/// }
/// ```
@Observable
@MainActor
final class CountdownCoordinator {
    // MARK: - Public State

    /// Current countdown value: 3/2/1 = counting, 0 = "GO" display, nil = inactive.
    private(set) var countdownValue: Int? = nil

    /// Whether a countdown is currently in progress.
    private(set) var isCountingDown: Bool = false

    // MARK: - Private State

    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    /// Called each time a count (3, 2, 1, GO) appears. The iPhone beeps here; the Watch
    /// stays silent (audio is unreliable when the wrist is down).
    @ObservationIgnored private let onCount: () -> Void

    // MARK: - Initialization

    init(onCount: @escaping () -> Void = {}) {
        self.onCount = onCount
    }

    // MARK: - Public Methods

    /// Counts down to `scheduledStartTime`, joining at whatever position matches the
    /// current time.
    ///
    /// - Parameters:
    ///   - scheduledStartTime: The absolute time the workout clock starts.
    ///   - completion: Called once the countdown has run to its end. Called right away,
    ///     without showing a countdown, if the start time has already passed (a late
    ///     join). Not called for a countdown that is cancelled or skipped.
    func startCountdown(
        scheduledStartTime: Date,
        completion: @escaping () -> Void = {}
    ) {
        // Cancel any existing countdown
        cancelCountdown()

        let timeUntilStart = scheduledStartTime.timeIntervalSince(Date())
        guard timeUntilStart > 0 else {
            completion()
            return
        }

        isCountingDown = true

        countdownTask = Task { [weak self] in
            guard let self else { return }

            // Calculate which count to join at (ceiling of seconds remaining)
            var currentCount = min(3, Int(ceil(timeUntilStart)))

            // Display each count and wait
            while currentCount > 0 && !Task.isCancelled {
                self.countdownValue = currentCount
                self.onCount()

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
            self.onCount()
            try? await Task.sleep(for: .milliseconds(400))

            guard !Task.isCancelled else { return }

            self.countdownValue = nil
            self.isCountingDown = false
            completion()
        }
    }

    /// Cancels any in-progress countdown.
    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
        isCountingDown = false
    }

    /// Hides the remaining countdown (a tap on the Watch's countdown screen). The workout
    /// still starts at its shared start date, so a skip can't run one device ahead of
    /// the other.
    func finishNow() {
        guard isCountingDown else { return }
        cancelCountdown()
    }
}
