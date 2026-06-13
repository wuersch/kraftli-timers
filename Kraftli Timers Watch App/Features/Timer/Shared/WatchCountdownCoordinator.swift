//
//  WatchCountdownCoordinator.swift
//  Kraftli Timers Watch App
//
//  Coordinates pre-workout countdown on Apple Watch.
//  Handles joining a countdown in progress when started from iPhone.
//

import Foundation

/// Coordinates a pre-workout countdown on Apple Watch.
///
/// Unlike the iOS coordinator, this version:
/// - Does not play audio (unreliable when wrist is down)
/// - Handles joining a countdown in progress (when iPhone leads)
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

    /// Stored so `finishNow()` can fire the start when the user taps to skip
    /// the remaining countdown. The `Date?` is the start anchor: `nil` on natural
    /// completion (start at local now), or the shared `scheduledStartTime` on skip.
    private var completion: ((Date?) -> Void)?

    /// The absolute time this countdown is counting toward. Passed to `completion`
    /// by `finishNow()` so a tap-to-skip anchors to the shared leader time (ADR-005,
    /// finding 5) instead of starting early at local now.
    private var scheduledStartTime: Date?

    // MARK: - Public Methods

    /// Starts a countdown that completes at the specified absolute time.
    ///
    /// If the scheduled start time is in the past, the countdown is skipped
    /// and completion is called immediately. Otherwise, the watch joins
    /// the countdown at whatever position matches the current time.
    ///
    /// - Parameters:
    ///   - scheduledStartTime: The absolute time when the timer should start.
    ///   - completion: Called when countdown completes and timer should start. Receives the
    ///     start anchor: `nil` on natural completion, or `scheduledStartTime` on tap-to-skip.
    func startCountdown(
        scheduledStartTime: Date,
        completion: @escaping (Date?) -> Void
    ) {
        // Cancel any existing countdown
        cancelCountdown()

        let timeUntilStart = scheduledStartTime.timeIntervalSince(Date())

        // If we're already past the start time, skip countdown entirely
        guard timeUntilStart > 0 else {
            completion(nil)
            return
        }

        isCountingDown = true
        self.completion = completion
        self.scheduledStartTime = scheduledStartTime

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

            // Show "GO" (represented as 0)
            self.countdownValue = 0

            // Brief display of "GO" before starting
            try? await Task.sleep(for: .milliseconds(400))

            guard !Task.isCancelled else { return }

            self.countdownValue = nil
            self.isCountingDown = false
            self.scheduledStartTime = nil

            // Natural completion: anchor at local now (≈ scheduled + GO display), matching the
            // iPhone's natural countdown path, so both devices stay in lockstep.
            completion(nil)
        }
    }

    /// Cancels any in-progress countdown.
    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
        isCountingDown = false
        completion = nil
        scheduledStartTime = nil
    }

    /// Skips the remaining countdown and starts immediately (tap-to-start).
    ///
    /// Mirrors Apple's Workout app: tapping during the 3-2-1 jumps straight to
    /// the workout. Fires the stored completion exactly once; cancelling the
    /// task first makes the in-flight `countdownTask`'s own `completion()` call
    /// short-circuit on its `Task.isCancelled` guard, so there's no double-fire.
    func finishNow() {
        guard isCountingDown else { return }
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
        isCountingDown = false
        let startNow = completion
        let anchor = scheduledStartTime
        completion = nil
        scheduledStartTime = nil
        // Skip the animation, not the synchronized start: anchor to the shared scheduled time
        // (ADR-005, finding 5) so a tap before `scheduled` doesn't start the Watch ahead of the
        // leader. The standalone caller ignores this anchor (no leader to sync with).
        startNow?(anchor)
    }
}
