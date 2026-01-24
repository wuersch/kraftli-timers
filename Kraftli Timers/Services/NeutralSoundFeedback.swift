//
//  NeutralSoundFeedback.swift
//  Kraftli Timers
//
//  Audio feedback using system sounds instead of the cheering sound.
//

import AVFoundation

/// Audio feedback provider that uses neutral system sounds.
///
/// Plays system sound 1057 (Begin) for all audio cues instead of
/// the crowd cheering sound. For workout completion, plays the
/// sound three times in sequence.
final class NeutralSoundFeedback: FeedbackProvider {
    func onIntervalComplete() {
        AudioServicesPlaySystemSound(1057)
    }

    func onWarning() {
        // No warning sound
    }

    func onWorkoutComplete() {
        // Play system sound 1057 three times with delays
        AudioServicesPlaySystemSound(1057)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            AudioServicesPlaySystemSound(1057)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            AudioServicesPlaySystemSound(1057)
        }
    }

    func onStart() {
        // No start sound
    }
}
