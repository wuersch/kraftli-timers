//
//  WatchHapticFeedback.swift
//  Kraftli Timers Watch App
//
//  Haptic feedback implementation for watchOS.
//  Conforms to AudioFeedbackProvider so it can be used with existing timer models.
//

import WatchKit

/// Provides haptic feedback on watchOS using WKInterfaceDevice.
final class WatchHapticFeedback: AudioFeedbackProvider {
    private let device = WKInterfaceDevice.current()

    func playStart() {
        device.play(.start)
    }

    func playIntervalComplete() {
        device.play(.notification)
    }

    func playWarning() {
        device.play(.retry)
    }

    func playWorkoutComplete() {
        device.play(.success)
    }
}
