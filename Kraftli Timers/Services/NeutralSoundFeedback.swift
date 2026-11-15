//
//  NeutralSoundFeedback.swift
//  Kraftli Timers
//
//  Audio feedback using neutral beep sounds instead of the cheering sound.
//

import Foundation

/// Audio feedback provider that uses neutral beep sounds.
///
/// Plays a beep for all audio cues instead of the crowd cheering sound.
/// For workout completion, plays the beep three times in sequence.
/// Playback goes through `TimerSounds`, which keeps all audio work off the main thread.
final class NeutralSoundFeedback: FeedbackProvider {
    init() {
        TimerSounds.shared.prepare([.beep])
    }

    func onIntervalComplete() {
        TimerSounds.shared.play(.beep)
    }

    func onWarning() {
        // No warning sound
    }

    func onWorkoutComplete() {
        // Play beep three times with delays
        TimerSounds.shared.play(.beep)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            TimerSounds.shared.play(.beep)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            TimerSounds.shared.play(.beep)
        }
    }
}
