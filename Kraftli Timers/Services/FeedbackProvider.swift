//
//  FeedbackProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 21.12.2025.
//

/// Protocol for providing feedback during workouts.
///
/// Implementations can provide audio (iPhone) or haptic (Watch) feedback.
/// Method names use `on*()` convention to indicate events rather than
/// implementation details.
protocol FeedbackProvider {
    func onIntervalComplete()
    func onWarning()
    func onWorkoutComplete()
    func onStart()
}
