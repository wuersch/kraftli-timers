//
//  SystemSoundFeedback.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

import AVFoundation
import os

final class SystemSoundFeedback: FeedbackProvider {
    private var completionPlayer: AVAudioPlayer?
    private var intervalPlayer: AVAudioPlayer?

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

        // Preload interval beep sound
        if let url = Bundle.main.url(forResource: "beep", withExtension: "wav") {
            do {
                intervalPlayer = try AVAudioPlayer(contentsOf: url)
                intervalPlayer?.volume = 1.0
                intervalPlayer?.prepareToPlay()

                // Prime audio hardware with silent playback to avoid first-play static
                intervalPlayer?.volume = 0
                intervalPlayer?.play()
                intervalPlayer?.stop()
                intervalPlayer?.currentTime = 0
                intervalPlayer?.volume = 1.0
            } catch {
                Logger.audio.error("Failed to load interval beep: \(error.localizedDescription)")
            }
        } else {
            Logger.audio.warning("Interval beep file not found in bundle")
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

    func onIntervalComplete() {
        intervalPlayer?.currentTime = 0
        intervalPlayer?.play()
    }

    func onWarning() {
        // no warning sound for now
    }

    func onWorkoutComplete() {
        completionPlayer?.currentTime = 0
        completionPlayer?.play()
    }

    func onStart() {
        // no start sound for now
    }
}
