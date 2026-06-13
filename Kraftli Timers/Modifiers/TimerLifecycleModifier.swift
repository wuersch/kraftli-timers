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

    /// When true, the Watch handled the HKWorkoutSession (Scenario C/D).
    /// iPhone should skip its own HealthKit save to avoid duplicates.
    var watchHandledWorkout: Bool = false

    /// Pre-generated ID for the WorkoutLog, used for correlation with Watch's
    /// HealthKit UUID. Set when an iPhone-initiated workout sent a `StartTimerMessage`
    /// with this ID; Watch echoes it back in `WorkoutSessionEndedMessage`.
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
    /// Whether an HK mirrored session is currently the authoritative control channel.
    /// While true the background auto-pause is skipped (ADR-005): the timer is wall-clock
    /// anchored and the still-running Watch/HK session, not scenePhase, drives pause/resume.
    let isMirroredSessionActive: () -> Bool
    /// Called when the app returns to the foreground (scenePhase `.active`). Used to
    /// re-snap local state to the live mirrored session after a background interval.
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
                    // ADR-005: while a mirrored HK session is active it is the sole control
                    // channel and the timer is wall-clock anchored, so don't local-pause on
                    // background — the iPhone would freeze and fall behind the still-running
                    // Watch by the whole background duration. The display self-corrects from
                    // `startDate` on foreground.
                    if timer.isRunning && !isMirroredSessionActive() {
                        onPause()
                    }
                case .active:
                    // Re-snap to the live mirrored session state (a Watch pause/resume during
                    // background may not have moved local state).
                    onForeground()
                default:
                    break
                }
            }
            .onChange(of: timer.didComplete) { _, didComplete in
                // Key off the model's explicit completion signal, not a zero-crossing of
                // totalTimeRemaining — a pause(at:) clamp or stray tick must not "complete" the workout.
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
    ///   - isMirroredSessionActive: When true, skip the background auto-pause (ADR-005)
    ///   - onForeground: Called on scenePhase `.active` to reconcile with the live session
    func timerLifecycle<T: WorkoutTimer>(
        timer: T,
        session: TimerSessionState,
        onPause: @escaping () -> Void,
        onDisappear: @escaping () -> Void,
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
        isMirroredSessionActive: @escaping () -> Bool = { false },
        onForeground: @escaping () -> Void = { }
    ) -> some View {
        modifier(TimerLifecycleModifier(
            timer: timer,
            session: session,
            onPause: onPause,
            onDisappear: onDisappear,
            onWorkoutCompleted: onWorkoutCompleted,
            isMirroredSessionActive: isMirroredSessionActive,
            onForeground: onForeground
        ))
    }
}
