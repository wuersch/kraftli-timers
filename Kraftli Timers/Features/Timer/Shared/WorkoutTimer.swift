//
//  WorkoutTimer.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

protocol WorkoutTimer: AnyObject {
    var totalTimeRemaining: TimeInterval { get }
    var totalDuration: TimeInterval { get }
    var isRunning: Bool { get }

    /// Reps completed (EMOM timers)
    var completedReps: Int? { get }
    /// Rounds completed (AMRAP timers)
    var completedRounds: Int? { get }

    func start()
    func pause()
    func reset()
}
