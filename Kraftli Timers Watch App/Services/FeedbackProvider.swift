//
//  FeedbackProvider.swift
//  Kraftli Timers Watch App
//
//  Protocol for providing feedback during workouts.
//  Duplicated in Watch App target since protocols cannot be shared across targets.
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
