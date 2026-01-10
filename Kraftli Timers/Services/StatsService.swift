//
//  StatsService.swift
//  Kraftli Timers
//
//  Service for computing workout statistics from logged data.
//

import Foundation

/// Aggregated statistics for a single exercise.
struct ExerciseStats: Identifiable {
    let exerciseName: String
    let muscleGroup: MuscleGroup?
    let totalMinutes: Int
    let totalReps: Int?
    let totalRounds: Int?
    let workoutCount: Int

    var id: String { exerciseName }

    /// Summary text (e.g., "45 min · 3 workouts").
    var summaryText: String {
        let duration = "\(totalMinutes) min"
        let count = workoutCount == 1 ? "1 workout" : "\(workoutCount) workouts"
        return "\(duration)\(UISeparator.dot)\(count)"
    }
}

/// Data point for chart display.
struct ChartDataPoint: Identifiable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}

/// Protocol for computing workout statistics.
///
/// Abstracted as a protocol to enable testing with mock data.
protocol StatsService {
    /// Filters workouts to those within the specified time period.
    ///
    /// - Parameters:
    ///   - workouts: All available workout logs.
    ///   - period: The time period to filter by.
    ///   - referenceDate: The reference date (typically today).
    /// - Returns: Workouts within the specified period.
    func filterByPeriod(
        workouts: [WorkoutLog],
        period: TimePeriod,
        referenceDate: Date
    ) -> [WorkoutLog]

    /// Computes total minutes per day/month for chart display.
    ///
    /// - Parameters:
    ///   - workouts: Workout logs to aggregate (should be pre-filtered by period).
    ///   - period: The time period (determines grouping granularity).
    /// - Returns: Array of data points with date and total minutes.
    func totalMinutesPerDay(
        workouts: [WorkoutLog],
        period: TimePeriod
    ) -> [ChartDataPoint]

    /// Groups workouts by exercise and computes aggregate statistics.
    ///
    /// - Parameters:
    ///   - workouts: Workout logs to aggregate.
    ///   - exercises: Available exercises (for muscle group lookup).
    /// - Returns: Array of exercise statistics, sorted by total minutes descending.
    func groupedByExercise(
        workouts: [WorkoutLog],
        exercises: [Exercise]
    ) -> [ExerciseStats]
}

/// Default implementation of StatsService.
final class DefaultStatsService: StatsService {

    func filterByPeriod(
        workouts: [WorkoutLog],
        period: TimePeriod,
        referenceDate: Date = Date()
    ) -> [WorkoutLog] {
        let range = period.dateRange(from: referenceDate)
        return workouts.filter { workout in
            workout.date >= range.start && workout.date <= range.end
        }
    }

    func totalMinutesPerDay(
        workouts: [WorkoutLog],
        period: TimePeriod
    ) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let grouping = period.chartGrouping

        // Group workouts by date component
        var grouped: [Date: Int] = [:]

        for workout in workouts {
            let components: Set<Calendar.Component> = grouping == .month
                ? [.year, .month]
                : [.year, .month, .day]

            let dateComponents = calendar.dateComponents(components, from: workout.date)
            guard let groupDate = calendar.date(from: dateComponents) else { continue }

            let minutes = Int(workout.durationSeconds / 60)
            grouped[groupDate, default: 0] += minutes
        }

        // Convert to sorted array of data points
        return grouped
            .map { ChartDataPoint(date: $0.key, minutes: $0.value) }
            .sorted { $0.date < $1.date }
    }

    func groupedByExercise(
        workouts: [WorkoutLog],
        exercises: [Exercise]
    ) -> [ExerciseStats] {
        // Build exercise lookup by name
        let exercisesByName = Dictionary(
            uniqueKeysWithValues: exercises.map { ($0.name, $0) }
        )

        // Group workouts by exercise name
        var grouped: [String: [WorkoutLog]] = [:]
        for workout in workouts {
            grouped[workout.exerciseName, default: []].append(workout)
        }

        // Compute statistics for each exercise
        var stats: [ExerciseStats] = []

        for (exerciseName, exerciseWorkouts) in grouped {
            let exercise = exercisesByName[exerciseName]

            let totalMinutes = exerciseWorkouts.reduce(0) { sum, workout in
                sum + Int(workout.durationSeconds / 60)
            }

            let totalReps = exerciseWorkouts.compactMap(\.repsCompleted).reduce(0, +)
            let totalRounds = exerciseWorkouts.compactMap(\.roundsCompleted).reduce(0, +)

            stats.append(ExerciseStats(
                exerciseName: exerciseName,
                muscleGroup: exercise?.muscleGroup,
                totalMinutes: totalMinutes,
                totalReps: totalReps > 0 ? totalReps : nil,
                totalRounds: totalRounds > 0 ? totalRounds : nil,
                workoutCount: exerciseWorkouts.count
            ))
        }

        // Sort by total minutes descending
        return stats.sorted { $0.totalMinutes > $1.totalMinutes }
    }
}
