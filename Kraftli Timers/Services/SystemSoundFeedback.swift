//
//  SystemSoundFeedback.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

import AVFoundation
import os

final class SystemSoundFeedback: AudioFeedbackProvider {
    private var completionPlayer: AVAudioPlayer?

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
            Logger.audio.error("Audio session configuration failed: \(error.localizedDescription)")
        }

        // Preload completion sound
        if let url = Bundle.main.url(
            forResource: "764274__shangusburger__crwdcheer_short-affirmative-cheer_shanevincent_gsc24_spacedomni-mk012",
            withExtension: "wav"
        ) {
            do {
                completionPlayer = try AVAudioPlayer(contentsOf: url)
                completionPlayer?.prepareToPlay()
            } catch {
                Logger.audio.error("Failed to load completion sound: \(error.localizedDescription)")
            }
        } else {
            Logger.audio.warning("Completion sound file not found in bundle")
        }
    }

    func playIntervalComplete() {
        AudioServicesPlaySystemSound(1057)  // Begin
    }

    func playWarning() {
        // no warning sound for now
    }

    func playWorkoutComplete() {
        completionPlayer?.currentTime = 0
        completionPlayer?.play()
    }

    func playStart() {
        // no start sound for now
    }
}
