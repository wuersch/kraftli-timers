//
//  WatchTimerLifecycleModifier.swift
//  Kraftli Timers Watch App
//
//  Manages WKExtendedRuntimeSession to keep the timer running when wrist is lowered.
//  watchOS doesn't have isIdleTimerDisabled, so we use extended runtime sessions instead.
//

import SwiftUI
import WatchKit

/// A view modifier that manages an extended runtime session to keep the timer running
/// during workouts, even when the wrist is lowered and the display dims.
/// The session starts when the timer starts running and ends when the timer stops
/// or the view disappears.
struct WatchTimerLifecycleModifier<Timer: WorkoutTimer>: ViewModifier {
    let timer: Timer
    let onPause: () -> Void

    @State private var session: WKExtendedRuntimeSession?

    func body(content: Content) -> some View {
        content
            .onChange(of: timer.isRunning) { _, isRunning in
                if isRunning {
                    startExtendedSession()
                } else {
                    endExtendedSession()
                }
            }
            .onDisappear {
                endExtendedSession()
            }
    }

    // MARK: - Session Management

    private func startExtendedSession() {
        // Don't start a new session if one is already active
        guard session == nil else { return }

        let newSession = WKExtendedRuntimeSession()
        newSession.start()
        session = newSession
    }

    private func endExtendedSession() {
        session?.invalidate()
        session = nil
    }
}

extension View {
    /// Adds watch timer lifecycle handling to keep the timer running during workouts.
    ///
    /// Uses `WKExtendedRuntimeSession` to keep the timer running even when the
    /// wrist is lowered and the display dims. The session automatically ends when
    /// the timer stops or when the view disappears.
    ///
    /// - Parameters:
    ///   - timer: The workout timer to observe for running state changes
    ///   - onPause: Called when the timer should pause (reserved for future use)
    func watchTimerLifecycle<T: WorkoutTimer>(timer: T, onPause: @escaping () -> Void) -> some View {
        modifier(WatchTimerLifecycleModifier(timer: timer, onPause: onPause))
    }
}
