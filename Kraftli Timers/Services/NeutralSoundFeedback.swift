//
//  NeutralSoundFeedback.swift
//  Kraftli Timers
//
//  Audio feedback using neutral beep sounds instead of the cheering sound.
//

import AVFoundation
import os

/// Audio feedback provider that uses neutral beep sounds.
///
/// Plays a beep for all audio cues instead of the crowd cheering sound.
/// For workout completion, plays the beep three times in sequence.
final class NeutralSoundFeedback: FeedbackProvider {
    private var beepPlayer: AVAudioPlayer?

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

        // Preload beep sound
        if let url = Bundle.main.url(forResource: "beep", withExtension: "wav") {
            do {
                beepPlayer = try AVAudioPlayer(contentsOf: url)
                beepPlayer?.volume = 1.0
                beepPlayer?.prepareToPlay()

                // Prime audio hardware with silent playback to avoid first-play static
                beepPlayer?.volume = 0
                beepPlayer?.play()
                beepPlayer?.stop()
                beepPlayer?.currentTime = 0
                beepPlayer?.volume = 1.0
            } catch {
                Logger.audio.error("Failed to load beep sound: \(error.localizedDescription)")
            }
        } else {
            Logger.audio.warning("Beep sound file not found in bundle")
        }
    }

    func onIntervalComplete() {
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
    }

    func onWarning() {
        // No warning sound
    }

    func onWorkoutComplete() {
        // Play beep three times with delays
        beepPlayer?.currentTime = 0
        beepPlayer?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.beepPlayer?.currentTime = 0
            self?.beepPlayer?.play()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
            self?.beepPlayer?.currentTime = 0
            self?.beepPlayer?.play()
        }
    }

    func onStart() {
        // No start sound
    }
}
