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

    /// True for a workout ended early (UC-0005 extension 1a): the duration is the active
    /// time up to the stop, and the count is what was done so far.
    var stoppedEarly = false

    /// Set for a step of a session (UC-0015): the session's name and the run's ID. Such a
    /// step gets no Health workout of its own; the session gets one for all its steps.
    var sessionName: String?
    var sessionRunID: UUID?
}

extension WorkoutCompletionData {
    /// The report of a workout with `result`, run by the iPhone or the Watch.
    init(_ result: WorkoutResult, ownedByWatch: Bool, correlationID: UUID, stoppedEarly: Bool = false) {
        self.init(
            durationSeconds: result.duration,
            repsCompleted: result.reps,
            roundsCompleted: result.rounds,
            ownedByWatch: ownedByWatch,
            correlationID: correlationID,
            stoppedEarly: stoppedEarly
        )
    }
}

/// A view modifier that handles common timer lifecycle events:
/// - Pauses timer when app enters background
/// - Manages screen idle timer
/// - Triggers completion events
/// - Cleans up on disappear
struct TimerLifecycleModifier<Timer: TimerModel>: ViewModifier {
    /// The timer model being observed
    let timer: Timer
    /// The session state for hint/confetti management
    let session: TimerSessionState
    /// Called when the timer should be paused (background, etc.)
    let onPause: () -> Void
    /// Called when the view disappears
    let onDisappear: () -> Void
    /// Called when the workout completes (timer reaches zero, or declared done).
    let onWorkoutCompleted: () -> Void
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
            .onChange(of: timer.isCompleted) { _, isCompleted in
                guard isCompleted else { return }
                session.onTimerCompleted()
                onWorkoutCompleted()
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
    ///   - onWorkoutCompleted: Called when the workout completes
    ///   - pausesInBackground: Whether backgrounding the app pauses the workout
    ///   - onForeground: Called on scenePhase `.active`
    func timerLifecycle<T: TimerModel>(
        timer: T,
        session: TimerSessionState,
        onPause: @escaping () -> Void,
        onDisappear: @escaping () -> Void,
        onWorkoutCompleted: @escaping () -> Void = { },
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
