//
//  TimerLifecycleModifier.swift
//  Kraftli Timers
//
//  Handles common lifecycle events for timer views.
//

import SwiftUI

/// Workout completion data passed to the logging callback.
struct WorkoutCompletionData {
    let durationSeconds: TimeInterval
    let repsCompleted: Int?
    let roundsCompleted: Int?
}

/// A view modifier that handles common timer lifecycle events:
/// - Pauses timer when app enters background
/// - Manages screen idle timer
/// - Triggers completion events
/// - Logs completed workouts
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
    /// Called when the workout completes (timer reaches zero). Used for logging.
    let onWorkoutCompleted: ((WorkoutCompletionData) -> Void)?

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
                    let completionData = WorkoutCompletionData(
                        durationSeconds: timer.totalDuration,
                        repsCompleted: timer.completedReps,
                        roundsCompleted: timer.completedRounds
                    )
                    onWorkoutCompleted?(completionData)
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
    ///   - onWorkoutCompleted: Called when workout completes (timer reaches zero)
    func timerLifecycle<T: WorkoutTimer>(
        timer: T,
        session: TimerSessionState,
        onPause: @escaping () -> Void,
        onDisappear: @escaping () -> Void,
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil
    ) -> some View {
        modifier(TimerLifecycleModifier(
            timer: timer,
            session: session,
            onPause: onPause,
            onDisappear: onDisappear,
            onWorkoutCompleted: onWorkoutCompleted
        ))
    }
}
