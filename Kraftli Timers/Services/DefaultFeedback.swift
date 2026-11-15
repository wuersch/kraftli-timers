//
//  DefaultFeedback.swift
//  Kraftli Timers
//
//  Plays the timer's sounds: a beep per interval and a completion cue.
//

import Foundation

/// The production `FeedbackProvider`: beeps on each interval and plays the chosen
/// completion cue when the workout ends.
final class DefaultFeedback: FeedbackProvider {
    /// What plays when the workout completes.
    enum CompletionCue {
        /// A cheering crowd.
        case cheer
        /// Three short beeps.
        case tripleBeep
    }

    private let completionCue: CompletionCue

    /// The trailing beeps of `.tripleBeep`. Held so they can be cancelled when the
    /// timer goes away mid-cue (the workout screen was closed).
    private var trailingBeeps: Task<Void, Never>?

    init(completionCue: CompletionCue = .cheer) {
        self.completionCue = completionCue
        switch completionCue {
        case .cheer: TimerSounds.shared.prepare([.beep, .cheer])
        case .tripleBeep: TimerSounds.shared.prepare([.beep])
        }
    }

    isolated deinit {
        trailingBeeps?.cancel()
    }

    func onIntervalComplete() {
        TimerSounds.shared.play(.beep)
    }

    func onWarning() {
        // No warning sound
    }

    func onWorkoutComplete() {
        switch completionCue {
        case .cheer:
            TimerSounds.shared.play(.cheer)
        case .tripleBeep:
            TimerSounds.shared.play(.beep)
            trailingBeeps?.cancel()
            trailingBeeps = Task {
                for _ in 0..<2 {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    TimerSounds.shared.play(.beep)
                }
            }
        }
    }
}
