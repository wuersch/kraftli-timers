//
//  TimerLifecycleModifier.swift
//  Kraftli Timers
//
//  Handles common lifecycle events for timer views.
//

import SwiftUI

/// A view modifier that handles common timer lifecycle events:
/// - Pauses timer when app enters background
/// - Manages screen idle timer
/// - Triggers completion events
/// - Cleans up on disappear
struct TimerLifecycleModifier<Timer: WorkoutTimer>: ViewModifier {
    /// The timer model being observed
    let timer: Timer
    /// The session state for hint/confetti management
    let session: TimerSessionState
    /// Called when the timer should be paused (background, etc.)
    let onPause: () -> Void
    /// Called when the view disappears
    let onDisappear: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onDisappear {
                session.cleanup()
                onDisappear()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: timer.isRunning) { _, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background && timer.isRunning {
                    onPause()
                }
            }
            .onChange(of: timer.totalTimeRemaining) { oldValue, newValue in
                if oldValue > 0 && newValue == 0 {
                    session.onTimerCompleted()
                }
            }
    }
}

extension View {
    /// Adds timer lifecycle handling to a view.
    ///
    /// - Parameters:
    ///   - timer: The workout timer to observe
    ///   - session: The session state for hint/confetti
    ///   - onPause: Called when timer should pause (e.g., app backgrounded)
    ///   - onDisappear: Called when view disappears
    func timerLifecycle<T: WorkoutTimer>(
        timer: T,
        session: TimerSessionState,
        onPause: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) -> some View {
        modifier(TimerLifecycleModifier(
            timer: timer,
            session: session,
            onPause: onPause,
            onDisappear: onDisappear
        ))
    }
}
