//
//  TimerSounds.swift
//  Kraftli Timers
//
//  Plays the timer's sounds without touching the audio system on the main thread.
//

import AVFoundation
import os

/// The app's sounds — countdown beeps and completion sounds — and its audio session.
///
/// Every `AVAudioSession` and `AVAudioPlayer` call that may wait for the audio system
/// (`setCategory`, `setActive`, `prepareToPlay`, `play`) risks UI hangs on the main thread
/// (the "AVAudioSession Hang Risk" runtime warning). So all of them run on one private
/// **serial** queue: callers only enqueue work and return immediately. Because the queue runs
/// one block at a time in order, the session is always active and a sound loaded before the
/// first `play` — no race between setup and playback.
///
/// The players live only on that queue (thread confinement), which is why the class can be
/// `@unchecked Sendable`: the compiler can't see the confinement, so we promise it.
nonisolated final class TimerSounds: @unchecked Sendable {
    enum Sound {
        case beep
        case cheer

        fileprivate var resourceName: String {
            switch self {
            case .beep:
                "beep"
            case .cheer:
                "764274__shangusburger__crwdcheer_short-affirmative-cheer_shanevincent_gsc24_spacedomni-mk012"
            }
        }
    }

    static let shared = TimerSounds()


    private let queue = DispatchQueue(label: "com.kraftli.timers.sounds", qos: .userInteractive)

    // Confined to `queue`.
    private var players: [Sound: AVAudioPlayer] = [:]
    private var isSessionActive = false

    private init() {}

    /// Activates the audio session and loads `sounds` in the background, so the first
    /// `play` has no delay. Safe to call repeatedly.
    func prepare(_ sounds: [Sound]) {
        queue.async { [self] in
            activateSessionIfNeeded()
            for sound in sounds {
                _ = player(for: sound)
            }
        }
    }

    /// Plays `sound` from the start. Returns immediately.
    func play(_ sound: Sound) {
        queue.async { [self] in
            activateSessionIfNeeded()
            guard let player = player(for: sound) else { return }
            player.currentTime = 0
            player.play()
        }
    }

    // MARK: - On the queue

    /// Plays alongside other audio (music, podcasts) instead of interrupting it.
    private func activateSessionIfNeeded() {
        guard !isSessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isSessionActive = true
        } catch {
            Logger.audio.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    /// The loaded player for `sound`, loading and warming it up on first use.
    private func player(for sound: Sound) -> AVAudioPlayer? {
        if let player = players[sound] { return player }
        guard let url = Bundle.main.url(forResource: sound.resourceName, withExtension: "wav") else {
            Logger.audio.warning("Sound file not found in bundle: \(sound.resourceName)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            // Play silently once, so the audio hardware is warmed up and the first real
            // sound doesn't crackle.
            player.volume = 0
            player.play()
            player.stop()
            player.currentTime = 0
            player.volume = 1
            players[sound] = player
            return player
        } catch {
            Logger.audio.error("Failed to load sound \(sound.resourceName): \(error.localizedDescription)")
            return nil
        }
    }
}
