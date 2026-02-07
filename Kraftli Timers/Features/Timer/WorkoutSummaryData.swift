//
//  WorkoutSummaryData.swift
//  Kraftli Timers
//
//  Data model for workout summary screen, populated from Watch metrics.
//

import Foundation

/// Data model for the workout summary screen.
///
/// Contains all information needed to display a post-workout summary,
/// including exercise details and health metrics from Apple Watch.
struct WorkoutSummaryData: Identifiable {
    /// Unique identifier for SwiftUI sheet presentation.
    let id = UUID()
    /// Name of the exercise performed.
    let exerciseName: String

    /// Type of timer used (EMOM or AMRAP).
    let timerKind: TimerKind

    /// Total workout duration in seconds.
    let duration: TimeInterval

    /// Number of reps completed (EMOM only).
    let reps: Int?

    /// Number of rounds completed (AMRAP only).
    let rounds: Int?

    /// Whether the Apple Watch was involved in this workout session.
    /// When true, placeholder cards are shown for health metrics until data arrives.
    let watchHandledWorkout: Bool

    /// Average heart rate during the workout (beats per minute).
    var averageHeartRate: Double?

    /// Maximum heart rate during the workout (beats per minute).
    var maxHeartRate: Double?

    /// Active calories burned during the workout (kilocalories).
    var activeCalories: Double?

    /// Whether this summary has meaningful health data to display.
    ///
    /// Returns true if at least one health metric (HR or calories) is available.
    var hasHealthData: Bool {
        averageHeartRate != nil || maxHeartRate != nil || activeCalories != nil
    }

    /// Formatted duration string (e.g., "20 min" or "5:30").
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if seconds == 0 {
            return "\(minutes) min"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Secondary info line for the header (e.g., "EMOM · 100 reps" or "AMRAP · 5 rounds").
    var headerSubtitle: String {
        switch timerKind {
        case .emom:
            if let reps, reps > 0 {
                return "\(timerKind.rawValue) · \(reps) reps"
            }
            return timerKind.rawValue
        case .amrap:
            if let rounds, rounds > 0 {
                let unit = rounds == 1 ? "round" : "rounds"
                return "\(timerKind.rawValue) · \(rounds) \(unit)"
            }
            return timerKind.rawValue
        }
    }
}
