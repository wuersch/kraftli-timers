//
//  TimerChrome.swift
//  Kraftli Timers
//
//  What a timer screen shares with the view presenting it.
//

import SwiftUI

/// What a timer screen (`TimerScreen`) shares with the view that presents it
/// (`TimerRunnerView`, `SessionRunnerView`): the tap hint, the confetti, whether the
/// swipe-down is disabled, and a way to end the workout.
///
/// ## SwiftUI: one shared observable object instead of bindings
/// The presenting view owns it (`@State`) and hands it to the screen through
/// `TimerScreenLink`. Both read and change the same object, and `@Observable` updates
/// whichever views read a property. Nothing has to be mirrored through bindings and
/// `onChange` relays, and the screen needs no callback to register its cleanup.
@Observable
@MainActor
final class TimerChrome {
    // MARK: - Shared State

    /// Whether the tap hint shows. It hides a few seconds into a running workout.
    private(set) var showHint = true

    /// Set when the workout completes. The presenting view shows the confetti, since it
    /// outlives the timer into the summary, and hides it again (`.confetti(isPresented:)`).
    var showConfetti = false

    /// True while the countdown runs: a swipe-down then does nothing.
    var isSwipeDisabled = false

    /// Whether the timer has ever started (used to distinguish first start from resume).
    private(set) var hasEverStarted = false

    /// Ends the workout as a swipe-down does: stops it and, if it ran long enough, reports
    /// it as stopped early. Set by the timer screen; safe to call more than once.
    @ObservationIgnored var endWorkout: () -> Void = {}

    // MARK: - Private State
    @ObservationIgnored private var hintHideTask: Task<Void, Never>?

    // MARK: - Timer Events

    /// Call when the timer starts running.
    /// Schedules the hint to hide after 5 seconds.
    func onTimerStarted(isStillRunning: @escaping () -> Bool) {
        hasEverStarted = true
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

    /// Call when the timer is paused. Shows the hint immediately.
    func onTimerPaused() {
        withAnimation(.easeIn(duration: 0.3)) {
            showHint = true
        }
    }

    /// Call when the timer completes. Shows the hint and triggers the confetti.
    func onTimerCompleted() {
        showConfetti = true
        showHint = true
    }

    /// Call when the timer view disappears to clean up resources.
    func cleanup() {
        hintHideTask?.cancel()
        hintHideTask = nil
    }

    /// Returns to the state before a timer, for the next timer on the same screen (a
    /// session's next step).
    func reset() {
        cleanup()
        showHint = true
        isSwipeDisabled = false
        hasEverStarted = false
    }
}

// MARK: - Confetti

extension View {
    /// Shows the confetti while `isPresented`, unless turned off in Settings, and hides it
    /// again after 3 seconds.
    func confetti(isPresented: Binding<Bool>) -> some View {
        modifier(ConfettiOverlay(isPresented: isPresented))
    }
}

private struct ConfettiOverlay: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented && settings.confettiEnabled {
                    ConfettiView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                }
            }
            // `.task(id:)` restarts when the value changes, and cancels the running task.
            .task(id: isPresented) {
                guard isPresented else { return }
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                isPresented = false
            }
    }
}
