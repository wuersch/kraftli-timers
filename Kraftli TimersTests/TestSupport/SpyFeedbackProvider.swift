//
//  SpyFeedbackProvider.swift
//  Kraftli TimersTests
//

@testable import Kraftli_Timers

/// Records feedback events so tests can assert which sounds would have played.
final class SpyFeedbackProvider: FeedbackProvider {
    private(set) var startCount = 0
    private(set) var intervalCompleteCount = 0
    private(set) var warningCount = 0
    private(set) var workoutCompleteCount = 0

    func onStart() { startCount += 1 }
    func onIntervalComplete() { intervalCompleteCount += 1 }
    func onWarning() { warningCount += 1 }
    func onWorkoutComplete() { workoutCompleteCount += 1 }
}
