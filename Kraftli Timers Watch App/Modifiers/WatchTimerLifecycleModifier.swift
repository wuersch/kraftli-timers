//
//  WatchTimerLifecycleModifier.swift
//  Kraftli Timers Watch App
//
//  Manages WKExtendedRuntimeSession to prevent watch from sleeping during workouts.
//  watchOS doesn't have isIdleTimerDisabled, so we use extended runtime sessions instead.
//  Also pauses the timer when the app enters background.
//

import SwiftUI
import WatchKit

/// A view modifier that manages an extended runtime session to keep the watch awake
/// during active timer workouts. The session starts when the timer starts running
/// and ends when the timer stops or the view disappears.
///
/// Also pauses the timer when the app enters background to prevent haptics
/// from continuing to fire while the app is not visible.
struct WatchTimerLifecycleModifier<Timer: WorkoutTimer>: ViewModifier {
    let timer: Timer
    let onPause: () -> Void

    @State private var session: WKExtendedRuntimeSession?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: timer.isRunning) { _, isRunning in
                if isRunning {
                    startExtendedSession()
                } else {
                    endExtendedSession()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background && timer.isRunning {
                    onPause()
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
    /// Adds watch timer lifecycle handling to keep the screen awake during workouts.
    ///
    /// Uses `WKExtendedRuntimeSession` to prevent the watch from sleeping while
    /// the timer is running. The session automatically ends when the timer stops
    /// or when the view disappears.
    ///
    /// Also pauses the timer when the app enters background to stop haptic feedback.
    ///
    /// - Parameters:
    ///   - timer: The workout timer to observe for running state changes
    ///   - onPause: Called when the timer should pause (e.g., app backgrounded)
    func watchTimerLifecycle<T: WorkoutTimer>(timer: T, onPause: @escaping () -> Void) -> some View {
        modifier(WatchTimerLifecycleModifier(timer: timer, onPause: onPause))
    }
}
