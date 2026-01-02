//
//  TimerSessionState.swift
//  Kraftli Timers
//
//  Manages UI state for timer sessions (hint visibility, confetti).
//

import SwiftUI

/// Manages transient UI state during a timer session.
/// Handles hint visibility timing and confetti display.
@Observable
@MainActor
final class TimerSessionState {
    // MARK: - Published State
    private(set) var showHint = true
    private(set) var showConfetti = false

    // MARK: - Private State
    private var hintHideTask: Task<Void, Never>?
    private var confettiHideTask: Task<Void, Never>?

    // MARK: - Timer Event Handlers

    /// Call when the timer starts running.
    /// Schedules the hint to hide after 5 seconds.
    func onTimerStarted(isStillRunning: @escaping () -> Bool) {
        guard showHint else { return }

        hintHideTask?.cancel()
        hintHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, isStillRunning(), showHint else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                showHint = false
            }
        }
    }

    /// Call when the timer is paused.
    /// Shows the hint immediately.
    func onTimerPaused() {
        withAnimation(.easeIn(duration: 0.3)) {
            showHint = true
        }
    }

    /// Call when the timer completes (time reaches zero).
    /// Shows confetti and hint, schedules confetti to hide after 3 seconds.
    func onTimerCompleted() {
        showConfetti = true
        showHint = true

        confettiHideTask?.cancel()
        confettiHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            showConfetti = false
        }
    }

    /// Call when the view disappears to clean up resources.
    func cleanup() {
        hintHideTask?.cancel()
        confettiHideTask?.cancel()
        hintHideTask = nil
        confettiHideTask = nil
    }
}
