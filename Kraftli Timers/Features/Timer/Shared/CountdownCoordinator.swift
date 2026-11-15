//
//  CountdownCoordinator.swift
//  Kraftli Timers
//
//  Coordinates pre-workout countdown (3, 2, 1, GO) before timers start.
//  Provides a hook point for future HealthKit workout session integration.
//

#if os(iOS)
import Foundation

/// Coordinates a 3-second countdown before workouts begin.
///
/// The countdown provides time for users to get into position and establishes
/// a synchronized start time for iPhone-Watch coordination.
///
/// ## Usage
/// ```swift
/// @State private var countdown = CountdownCoordinator()
///
/// countdown.startCountdown(scheduledStartTime: Date() + 3.0) {
///     timerModel.start()
/// }
/// ```
///
/// ## HealthKit Hook
/// The `onCountdownComplete` callback provides a clean integration point
/// for future HealthKit workout session initialization.
@Observable
@MainActor
final class CountdownCoordinator {
    // MARK: - Public State

    /// Current countdown value: 3/2/1 = counting, 0 = "GO" display, nil = inactive.
    private(set) var countdownValue: Int? = nil

    /// Whether a countdown is currently in progress.
    private(set) var isCountingDown: Bool = false

    /// Optional callback invoked just before completion.
    /// Use this for HealthKit workout session initialization.
    var onCountdownComplete: (() -> Void)?

    // MARK: - Private State

    private var countdownTask: Task<Void, Never>?
    private var scheduledStartTime: Date?

    // MARK: - Initialization

    init() {
        TimerSounds.shared.prepare([.beep])
    }

    // MARK: - Public Methods

    /// Starts a countdown that completes at the specified absolute time.
    ///
    /// The countdown displays 3, 2, 1, GO with beeps on each count.
    /// Uses absolute timestamps for iPhone-Watch synchronization.
    ///
    /// - Parameters:
    ///   - scheduledStartTime: The absolute time when the timer should start.
    ///   - completion: Called when countdown completes and timer should start.
    func startCountdown(
        scheduledStartTime: Date,
        completion: @escaping () -> Void
    ) {
        // Cancel any existing countdown
        cancelCountdown()

        self.scheduledStartTime = scheduledStartTime
        isCountingDown = true

        countdownTask = Task { [weak self] in
            guard let self else { return }

            let timeUntilStart = scheduledStartTime.timeIntervalSince(Date())

            // If we're already past the start time, skip countdown
            guard timeUntilStart > 0 else {
                self.finishCountdown(completion: completion)
                return
            }

            // Calculate which count to start from (ceiling of seconds remaining)
            var currentCount = min(3, Int(ceil(timeUntilStart)))

            // Display each count and wait
            while currentCount > 0 && !Task.isCancelled {
                self.countdownValue = currentCount
                self.playBeep()

                // Wait until the next count
                let targetTime = scheduledStartTime.addingTimeInterval(-Double(currentCount - 1))
                let delay = targetTime.timeIntervalSince(Date())

                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }

                currentCount -= 1
            }

            guard !Task.isCancelled else { return }

            // Show "GO" (represented as 0)
            self.countdownValue = 0
            self.playBeep()

            // Brief display of "GO" before starting
            try? await Task.sleep(for: .milliseconds(400))

            guard !Task.isCancelled else { return }

            self.finishCountdown(completion: completion)
        }
    }

    /// Cancels any in-progress countdown.
    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
        isCountingDown = false
        scheduledStartTime = nil
    }

    // MARK: - Private Methods

    private func finishCountdown(completion: () -> Void) {
        // Invoke HealthKit hook before starting timer
        onCountdownComplete?()

        countdownValue = nil
        isCountingDown = false
        scheduledStartTime = nil

        completion()
    }

    private func playBeep() {
        TimerSounds.shared.play(.beep)
    }
}
#endif
