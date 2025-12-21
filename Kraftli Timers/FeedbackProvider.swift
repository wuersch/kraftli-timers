//
//  FeedbackProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

protocol FeedbackProvider {
    func playIntervalComplete()
    func playWarning()
    func playWorkoutComplete()
    func playStart()
}
