//
//  AudioFeedbackProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

protocol AudioFeedbackProvider {
    func playIntervalComplete()
    func playWarning()
    func playWorkoutComplete()
    func playStart()
}
