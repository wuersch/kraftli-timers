//
//  SystemSoundFeedback.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

/// Audio feedback with a beep per interval and a crowd cheer on completion.
///
/// Playback goes through `TimerSounds`, which keeps all audio work off the main thread.
final class SystemSoundFeedback: FeedbackProvider {
    init() {
        TimerSounds.shared.prepare([.beep, .cheer])
    }

    func onIntervalComplete() {
        TimerSounds.shared.play(.beep)
    }

    func onWarning() {
        // no warning sound for now
    }

    func onWorkoutComplete() {
        TimerSounds.shared.play(.cheer)
    }
}
