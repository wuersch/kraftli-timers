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

    /// True when the Watch owned the workout (ADR-006 §1): it saved the Health workout,
    /// so the iPhone must not save a duplicate.
    var ownedByWatch: Bool = false

    /// The workout ID, used as the WorkoutLog's ID. The Watch echoes it back in
    /// `WorkoutSessionEndedMessage` to link its HealthKit workout to this log.
    var correlationID: UUID?
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
    /// Whether going to the background pauses the workout. True only for a workout this
    /// iPhone owns; one the Watch owns keeps running there, and the display catches up
    /// from its state on foreground (ADR-006).
    let pausesInBackground: () -> Bool
    /// Called when the app returns to the foreground (scenePhase `.active`), e.g. to
    /// complete an owned workout whose time ran out while suspended.
    let onForeground: () -> Void

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
                switch newPhase {
                case .background:
                    if timer.isRunning && pausesInBackground() {
                        onPause()
                    }
                case .active:
                    onForeground()
                default:
                    break
                }
            }
            .onChange(of: timer.didComplete) { _, didComplete in
                // Key off the model's explicit completion signal, not a zero-crossing of
                // totalTimeRemaining — a stopped workout or stray tick must not "complete" it.
                guard didComplete else { return }
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

extension View {
    /// Adds timer lifecycle handling to a view.
    ///
    /// - Parameters:
    ///   - timer: The workout timer to observe
    ///   - session: The session state for hint/confetti
    ///   - onPause: Called when timer should pause (e.g., app backgrounded)
    ///   - onDisappear: Called when view disappears
    ///   - onWorkoutCompleted: Called when workout completes (timer reaches zero)
    ///   - pausesInBackground: Whether backgrounding the app pauses the workout
    ///   - onForeground: Called on scenePhase `.active`
    func timerLifecycle<T: WorkoutTimer>(
        timer: T,
        session: TimerSessionState,
        onPause: @escaping () -> Void,
        onDisappear: @escaping () -> Void,
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
        pausesInBackground: @escaping () -> Bool = { true },
        onForeground: @escaping () -> Void = { }
    ) -> some View {
        modifier(TimerLifecycleModifier(
            timer: timer,
            session: session,
            onPause: onPause,
            onDisappear: onDisappear,
            onWorkoutCompleted: onWorkoutCompleted,
            pausesInBackground: pausesInBackground,
            onForeground: onForeground
        ))
    }
}
