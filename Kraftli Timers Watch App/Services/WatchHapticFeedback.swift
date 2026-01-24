//
//  WatchHapticFeedback.swift
//  Kraftli Timers Watch App
//
//  Haptic feedback implementation for watchOS.
//

import WatchKit

/// Provides haptic feedback on watchOS using WKInterfaceDevice.
final class WatchHapticFeedback: FeedbackProvider {
    private let device = WKInterfaceDevice.current()

    func onStart() {
        // no haptics for now
    }

    func onIntervalComplete() {
        device.play(.notification)
    }

    func onWarning() {
        // no haptics for now
    }

    func onWorkoutComplete() {
        device.play(.success)
    }
}
