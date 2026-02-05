//
//  WatchTimerLifecycleModifier.swift
//  Kraftli Timers Watch App
//
//  Manages workout session pause/resume to keep the timer running when wrist is lowered.
//  HKWorkoutSession provides extended runtime (replaces WKExtendedRuntimeSession)
//  and also collects heart rate and calorie data via Watch sensors.
//

import SwiftUI
import WatchKit

/// A view modifier that pauses and resumes the workout session in sync with the timer.
///
/// The `HKWorkoutSession` itself is started and stopped by the timer view
/// (on countdown completion and workout completion respectively). This modifier
/// only handles the pause/resume lifecycle to keep session state in sync with
/// the timer's running state.
///
/// When `sessionManager` is nil (e.g., HealthKit unavailable), falls back to
/// `WKExtendedRuntimeSession` for basic keep-alive functionality.
struct WatchTimerLifecycleModifier<Timer: WorkoutTimer>: ViewModifier {
    let timer: Timer
    let sessionManager: WorkoutSessionManager?
    let onPause: () -> Void

    @State private var fallbackSession: WKExtendedRuntimeSession?

    func body(content: Content) -> some View {
        content
            .onChange(of: timer.isRunning) { _, isRunning in
                if let sessionManager {
                    // HealthKit session: pause/resume
                    if isRunning {
                        sessionManager.resume()
                    } else if !timer.isCompleted {
                        // Only pause if not completed - completion ends the session directly
                        sessionManager.pause()
                    }
                } else {
                    // Fallback: WKExtendedRuntimeSession for keep-alive
                    if isRunning {
                        startFallbackSession()
                    } else {
                        endFallbackSession()
                    }
                }
            }
            .onDisappear {
                endFallbackSession()
            }
    }

    // MARK: - Fallback Session (when HealthKit unavailable)

    private func startFallbackSession() {
        guard fallbackSession == nil else { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.start()
        fallbackSession = newSession
    }

    private func endFallbackSession() {
        fallbackSession?.invalidate()
        fallbackSession = nil
    }
}

extension View {
    /// Adds watch timer lifecycle handling to keep the timer running during workouts.
    ///
    /// When a `WorkoutSessionManager` is provided, pauses and resumes the
    /// `HKWorkoutSession` in sync with the timer. When nil, falls back to
    /// `WKExtendedRuntimeSession` for basic keep-alive.
    ///
    /// - Parameters:
    ///   - timer: The workout timer to observe for running state changes
    ///   - sessionManager: Optional workout session manager for HealthKit integration
    ///   - onPause: Called when the timer should pause (reserved for future use)
    func watchTimerLifecycle<T: WorkoutTimer>(
        timer: T,
        sessionManager: WorkoutSessionManager? = nil,
        onPause: @escaping () -> Void
    ) -> some View {
        modifier(WatchTimerLifecycleModifier(
            timer: timer,
            sessionManager: sessionManager,
            onPause: onPause
        ))
    }
}
