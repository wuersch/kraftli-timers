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

/// Aggregated statistics for a muscle group.
struct MuscleGroupStats: Identifiable {
    let muscleGroup: MuscleGroup
    let totalMinutes: Int

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
        exercises: [Exercise]
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
        exercises: [Exercise]
    ) -> [MuscleGroupStats]
}

/// Default implementation of StatsService.
final class DefaultStatsService: StatsService {

    // MARK: - Private Helpers

    /// Builds a lookup dictionary mapping exercise names to Exercise objects.
    private func buildExerciseLookup(_ exercises: [Exercise]) -> [String: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
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
        
        var totals: [Date: Int] = [:]
        for workout in workouts {
            let bucketDate = unit.normalizedStart(workout.date)
            totals[bucketDate, default: 0] += workout.durationMinutes
        }
        
        return buckets.map { bucketDate in
            ChartDataPoint(
                date: bucketDate,
                minutes: totals[bucketDate] ?? 0
            )
        }
    }
    
    func groupedByExercise(
        workouts: [WorkoutLog],
        exercises: [Exercise]
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

            let totalMinutes = exerciseWorkouts.reduce(0) { sum, workout in
                sum + Int(workout.durationMinutes)
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

    func groupedByMuscleGroup(
        workouts: [WorkoutLog],
        exercises: [Exercise]
    ) -> [MuscleGroupStats] {
        // Build exercise lookup by name
        let exercisesByName = buildExerciseLookup(exercises)

        // Group workouts by muscle group
        var grouped: [MuscleGroup: Int] = [:]

        for workout in workouts {
            // Skip workouts for exercises without muscle groups
            guard let exercise = exercisesByName[workout.exerciseName],
                  let muscleGroup = exercise.muscleGroup else {
                continue
            }

            let minutes = Int(workout.durationMinutes)
            grouped[muscleGroup, default: 0] += minutes
        }

        // Convert to stats array, sorted by enum order
        return MuscleGroup.allCases.compactMap { muscleGroup in
            guard let totalMinutes = grouped[muscleGroup] else {
                return nil
            }
            return MuscleGroupStats(muscleGroup: muscleGroup, totalMinutes: totalMinutes)
        }
    }
}
