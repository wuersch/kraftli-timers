//
//  AudioFeedbackProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

import AVFoundation

final class AudioFeedbackProvider: FeedbackProvider {
    private var audioPlayers: [AVAudioPlayer] = []

    init() {
        // Configure audio session
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playIntervalComplete() {
        AudioServicesPlaySystemSound(1057)  // Begin
    }

    func playWarning() {
        let soundID = SystemSoundID(1104)  // Short beep

        // Three short beep for count-down
        AudioServicesPlaySystemSound(1104)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            AudioServicesPlaySystemSound(soundID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            AudioServicesPlaySystemSound(soundID)
        }
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
