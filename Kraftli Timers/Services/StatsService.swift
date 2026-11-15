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
    /// Recorded seconds added up; rounded only for display (UC-0008).
    let totalSeconds: TimeInterval
    let totalReps: Int?
    let totalRounds: Int?
    let workoutCount: Int

    var id: String { exerciseName }

    /// Total time in whole minutes, rounded down for display.
    var totalMinutes: Int { totalSeconds.wholeMinutes }

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
    /// Recorded seconds in this bucket, added up before rounding.
    let seconds: TimeInterval

    /// Whole minutes, rounded down for display.
    var minutes: Int { seconds.wholeMinutes }

    var id: Date { date }
}

/// Aggregated statistics for a muscle group.
struct MuscleGroupStats: Identifiable {
    let muscleGroup: MuscleGroup
    /// Recorded seconds added up; rounded only for display.
    let totalSeconds: TimeInterval

    /// Whole minutes, rounded down for display.
    var totalMinutes: Int { totalSeconds.wholeMinutes }

    var id: MuscleGroup { muscleGroup }
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

    /// Computes total minutes per day/month/year for chart display.
    ///
    /// Generates data points for ALL time slots in the period (including zeros),
    /// matching Apple Health's approach of showing the complete time range.
    ///
    /// - Parameters:
    ///   - workouts: Workout logs to aggregate (should be pre-filtered by period).
    ///   - period: The time period (determines grouping granularity).
    ///   - referenceDate: The reference date for generating the full range.
    /// - Returns: Array of data points with date and total minutes.
    func totalMinutesPerBucket(
        workouts: [WorkoutLog],
        period: TimePeriod,
        referenceDate: Date
    ) -> [ChartDataPoint]

    /// Groups workouts by exercise and computes aggregate statistics.
    ///
    /// - Parameters:
    ///   - workouts: Workout logs to aggregate.
    ///   - exercises: Available exercises (for muscle group lookup).
    /// - Returns: Array of exercise statistics, sorted by total minutes descending.
    func groupedByExercise(
        workouts: [WorkoutLog],
        exercises: [ExerciseInfo]
    ) -> [ExerciseStats]

    /// Groups workouts by muscle group and computes aggregate statistics.
    ///
    /// Ignores exercises without muscle groups.
    ///
    /// - Parameters:
    ///   - workouts: Workout logs to aggregate.
    ///   - exercises: Available exercises (for muscle group lookup).
    /// - Returns: Array of muscle group statistics, sorted by enum order (fullBody, upperBody, lowerBody, core).
    func groupedByMuscleGroup(
        workouts: [WorkoutLog],
        exercises: [ExerciseInfo]
    ) -> [MuscleGroupStats]
}

/// Default implementation of StatsService.
final class DefaultStatsService: StatsService {

    // MARK: - Private Helpers

    /// Builds a lookup dictionary mapping exercise names to ExerciseInfo objects.
    private func buildExerciseLookup(_ exercises: [ExerciseInfo]) -> [String: ExerciseInfo] {
        Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Public Methods

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
    
    /// The returned data always spans the full TimePeriod range and includes zero-valued buckets.
    func totalMinutesPerBucket(
        workouts: [WorkoutLog],
        period: TimePeriod,
        referenceDate: Date = Date()
    ) -> [ChartDataPoint] {
        let periodRange = period.dateRange(from: referenceDate)
        guard periodRange.start <= periodRange.end else {
            return []
        }
        
        let unit = period.bucketUnit
        let buckets = period.allBuckets(referenceDate: referenceDate)
        
        // Add up seconds, not per-workout minutes: short For Time workouts must count (UC-0008).
        var totals: [Date: TimeInterval] = [:]
        for workout in workouts {
            let bucketDate = unit.normalizedStart(workout.date)
            totals[bucketDate, default: 0] += workout.durationSeconds
        }
        
        return buckets.map { bucketDate in
            ChartDataPoint(
                date: bucketDate,
                seconds: totals[bucketDate] ?? 0
            )
        }
    }
    
    func groupedByExercise(
        workouts: [WorkoutLog],
        exercises: [ExerciseInfo]
    ) -> [ExerciseStats] {
        // Build exercise lookup by name
        let exercisesByName = buildExerciseLookup(exercises)

        // Group workouts by exercise name
        var grouped: [String: [WorkoutLog]] = [:]
        for workout in workouts {
            grouped[workout.exerciseName, default: []].append(workout)
        }

        // Compute statistics for each exercise
        var stats: [ExerciseStats] = []

        for (exerciseName, exerciseWorkouts) in grouped {
            let exercise = exercisesByName[exerciseName]

            let totalSeconds = exerciseWorkouts.reduce(0) { $0 + $1.durationSeconds }

            let totalReps = exerciseWorkouts.compactMap(\.repsCompleted).reduce(0, +)
            let totalRounds = exerciseWorkouts.compactMap(\.roundsCompleted).reduce(0, +)

            stats.append(ExerciseStats(
                exerciseName: exerciseName,
                muscleGroup: exercise?.muscleGroup,
                totalSeconds: totalSeconds,
                totalReps: totalReps > 0 ? totalReps : nil,
                totalRounds: totalRounds > 0 ? totalRounds : nil,
                workoutCount: exerciseWorkouts.count
            ))
        }

        // Sort by total time descending
        return stats.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    func groupedByMuscleGroup(
        workouts: [WorkoutLog],
        exercises: [ExerciseInfo]
    ) -> [MuscleGroupStats] {
        // Build exercise lookup by name
        let exercisesByName = buildExerciseLookup(exercises)

        // Group workouts by muscle group
        var grouped: [MuscleGroup: TimeInterval] = [:]

        for workout in workouts {
            // Skip workouts for exercises not in the database
            guard let exercise = exercisesByName[workout.exerciseName] else {
                continue
            }

            grouped[exercise.muscleGroup, default: 0] += workout.durationSeconds
        }

        // Convert to stats array, sorted by enum order
        return MuscleGroup.allCases.compactMap { muscleGroup in
            guard let totalSeconds = grouped[muscleGroup] else {
                return nil
            }
            return MuscleGroupStats(muscleGroup: muscleGroup, totalSeconds: totalSeconds)
        }
    }
}
