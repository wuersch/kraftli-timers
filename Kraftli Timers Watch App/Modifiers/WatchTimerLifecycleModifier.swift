//
//  WatchTimerLifecycleModifier.swift
//  Kraftli Timers Watch App
//
//  Pauses and resumes the HealthKit workout session in step with the timer.
//

import SwiftUI

/// A view modifier that pauses and resumes the workout session in sync with the timer.
///
/// The `HKWorkoutSession` itself is started by `WatchWorkoutStarter` and ended by
/// `WatchWorkoutCoordinator`. This modifier only keeps its paused state in line with
/// the timer's running state, so Apple Health records active time only.
struct WatchTimerLifecycleModifier<Timer: WorkoutTimer>: ViewModifier {
    let timer: Timer
    let sessionManager: WorkoutSessionManager

    func body(content: Content) -> some View {
        content
            .onChange(of: timer.isRunning) { _, isRunning in
                if isRunning {
                    sessionManager.resume()
                } else if !timer.isCompleted {
                    // Only pause if not completed - completion ends the session directly
                    sessionManager.pause()
                }
            }
    }
}

extension View {
    /// Pauses and resumes the `HKWorkoutSession` in sync with the timer.
    ///
    /// - Parameters:
    ///   - timer: The workout timer to observe for running state changes
    ///   - sessionManager: The workout session manager owning the HealthKit session
    func watchTimerLifecycle<T: WorkoutTimer>(
        timer: T,
        sessionManager: WorkoutSessionManager
    ) -> some View {
        modifier(WatchTimerLifecycleModifier(timer: timer, sessionManager: sessionManager))
    }
}
