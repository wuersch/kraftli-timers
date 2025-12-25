//
//  AudioFeedbackProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

import AVFoundation

final class AudioFeedbackProvider: FeedbackProvider {
    init() {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session configuration failed - continue without audio feedback
        }
    }

    func playIntervalComplete() {
        AudioServicesPlaySystemSound(1057)  // Begin
    }

    func playWarning() {
        // no warning sound for now
    }

    func playWorkoutComplete() {
        let soundID = SystemSoundID(1057)

        // Triple beep for completion
        AudioServicesPlaySystemSound(soundID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AudioServicesPlaySystemSound(soundID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioServicesPlaySystemSound(soundID)
        }
    }

    func playStart() {
        // no start sound for now
    }
}
