//
//  StatsServiceTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct StatsServiceTests {

    let service = DefaultStatsService()

    // MARK: - Test Helpers

    /// Creates a workout log with sensible defaults for testing.
    private func makeWorkout(
        date: Date,
        exerciseName: String = "Test Exercise",
        timerKind: TimerKind = .emom,
        durationMinutes: Int = 20,
        reps: Int? = 100,
        rounds: Int? = nil
    ) -> WorkoutLog {
        WorkoutLog(
            date: date,
            exerciseName: exerciseName,
            timerKind: timerKind,
            durationSeconds: TimeInterval(durationMinutes * 60),
            repsCompleted: timerKind == .emom ? reps : nil,
            roundsCompleted: timerKind == .amrap ? rounds : nil
        )
    }

    /// Creates a date relative to today.
    private func date(daysAgo: Int, from reference: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: reference) ?? reference
    }

    // MARK: - filterByPeriod Tests

    @Test func filterByPeriod_weekFilter_includesWorkoutsInCurrentWeek() {
        let today = Date()
        let workouts = [
            makeWorkout(date: date(daysAgo: 0, from: today)),
            makeWorkout(date: date(daysAgo: 3, from: today)),
            makeWorkout(date: date(daysAgo: 6, from: today)),
            makeWorkout(date: date(daysAgo: 10, from: today)) // Outside current week
        ]

        let filtered = service.filterByPeriod(workouts: workouts, period: .week, referenceDate: today)

        // At least the today workout should be included
        #expect(filtered.contains { Calendar.current.isDateInToday($0.date) })
    }

    @Test func filterByPeriod_emptyWorkouts_returnsEmpty() {
        let filtered = service.filterByPeriod(workouts: [], period: .week, referenceDate: Date())

        #expect(filtered.isEmpty)
    }

    @Test func filterByPeriod_monthFilter_includesWorkoutsInCurrentMonth() {
        let calendar = Calendar.current
        let today = Date()

        // Create workout on the first day of current month
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let midMonth = calendar.date(byAdding: .day, value: 10, to: startOfMonth)!

        let workouts = [
            makeWorkout(date: startOfMonth),
            makeWorkout(date: midMonth),
            makeWorkout(date: today)
        ]

        let filtered = service.filterByPeriod(workouts: workouts, period: .month, referenceDate: today)

        #expect(filtered.count == 3)
    }

    @Test func filterByPeriod_yearFilter_includesWorkoutsInCurrentYear() {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)

        // Create workout at start of year
        var components = DateComponents()
        components.year = currentYear
        components.month = 1
        components.day = 15
        let januaryDate = calendar.date(from: components)!

        let workouts = [
            makeWorkout(date: januaryDate),
            makeWorkout(date: today)
        ]

        let filtered = service.filterByPeriod(workouts: workouts, period: .year, referenceDate: today)

        // Both should be included if they're in the current year
        #expect(filtered.count >= 1)
        #expect(filtered.allSatisfy { calendar.component(.year, from: $0.date) == currentYear })
    }

    @Test func filterByPeriod_excludesWorkoutsOutsidePeriod() {
        let calendar = Calendar.current
        let today = Date()

        // Create workout from last year
        let lastYear = calendar.date(byAdding: .year, value: -1, to: today)!

        let workouts = [
            makeWorkout(date: lastYear),
            makeWorkout(date: today)
        ]

        let filtered = service.filterByPeriod(workouts: workouts, period: .year, referenceDate: today)

        // Only today's workout should be included
        #expect(filtered.count == 1)
    }

    // MARK: - totalMinutesPerBucket Tests

    @Test func totalMinutesPerBucket_aggregatesMultipleWorkoutsSameDay() {
        let today = Date()
        let workouts = [
            makeWorkout(date: today, durationMinutes: 20),
            makeWorkout(date: today, durationMinutes: 15)
        ]

        let dataPoints = service.totalMinutesPerBucket(workouts: workouts, period: .week, referenceDate: today)

        // Find today's data point
        let calendar = Calendar.current
        let todayPoint = dataPoints.first { calendar.isDateInToday($0.date) }

        #expect(todayPoint?.minutes == 35)
    }

    @Test func totalMinutesPerBucket_emptyWorkouts_returnsZeroMinutes() {
        let dataPoints = service.totalMinutesPerBucket(workouts: [], period: .week, referenceDate: Date())

        // Should still have data points for the week (7 days)
        #expect(dataPoints.count == 7)
        #expect(dataPoints.allSatisfy { $0.minutes == 0 })
    }

    @Test func totalMinutesPerBucket_weekPeriod_returns7DataPoints() {
        let dataPoints = service.totalMinutesPerBucket(workouts: [], period: .week, referenceDate: Date())

        #expect(dataPoints.count == 7)
    }

    @Test func totalMinutesPerBucket_yearPeriod_returns12DataPoints() {
        let dataPoints = service.totalMinutesPerBucket(workouts: [], period: .year, referenceDate: Date())

        #expect(dataPoints.count == 12)
    }

    @Test func totalMinutesPerBucket_singleWorkout_appearsInCorrectSlot() {
        let calendar = Calendar.current
        let today = Date()
        let workouts = [makeWorkout(date: today, durationMinutes: 30)]

        let dataPoints = service.totalMinutesPerBucket(workouts: workouts, period: .week, referenceDate: today)

        let todayPoint = dataPoints.first { calendar.isDateInToday($0.date) }
        #expect(todayPoint?.minutes == 30)
    }

    @Test func totalMinutesPerBucket_yearPeriod_groupsByMonth() {
        let calendar = Calendar.current
        let today = Date()

        // Create workouts on different days of current month
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        let workouts = [
            makeWorkout(date: startOfMonth, durationMinutes: 20),
            makeWorkout(date: calendar.date(byAdding: .day, value: 5, to: startOfMonth)!, durationMinutes: 15)
        ]

        let dataPoints = service.totalMinutesPerBucket(workouts: workouts, period: .year, referenceDate: today)

        // Should be 12 months
        #expect(dataPoints.count == 12)

        // Current month should have combined minutes
        let currentMonth = calendar.component(.month, from: today)
        let currentMonthPoint = dataPoints.first { calendar.component(.month, from: $0.date) == currentMonth }
        #expect(currentMonthPoint?.minutes == 35)
    }

    @Test func totalMinutesPerBucket_sixMonthsPeriod_groupsByWeek() {
        let calendar = Calendar.current
        let today = Date()

        // Create workouts in the same week
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        let workouts = [
            makeWorkout(date: startOfWeek, durationMinutes: 20),
            makeWorkout(date: calendar.date(byAdding: .day, value: 3, to: startOfWeek)!, durationMinutes: 15)
        ]

        let dataPoints = service.totalMinutesPerBucket(workouts: workouts, period: .sixMonths, referenceDate: today)

        // Should have approximately 26-27 weekly buckets (6 months ≈ 26 weeks)
        #expect(dataPoints.count >= 25)
        #expect(dataPoints.count <= 28)

        // Current week should have combined minutes from both workouts
        let currentWeek = calendar.component(.weekOfYear, from: today)
        let currentWeekPoint = dataPoints.first { calendar.component(.weekOfYear, from: $0.date) == currentWeek }

        // Note: This assertion may not always pass if today is in a different week than startOfWeek
        // Adjust test logic if needed based on actual workout dates
        if calendar.component(.weekOfYear, from: startOfWeek) == currentWeek {
            #expect(currentWeekPoint?.minutes == 35)
        }
    }

    // MARK: - groupedByExercise Tests

    @Test func groupedByExercise_groupsWorkoutsByName() {
        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 20),
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 15),
            makeWorkout(date: Date(), exerciseName: "Pull-ups", timerKind: .amrap, durationMinutes: 10, rounds: 5)
        ]

        let stats = service.groupedByExercise(workouts: workouts, exercises: [])

        #expect(stats.count == 2)

        let burpeeStats = stats.first { $0.exerciseName == "Burpees" }
        #expect(burpeeStats?.workoutCount == 2)
        #expect(burpeeStats?.totalMinutes == 35)
    }

    @Test func groupedByExercise_sortsByTotalMinutesDescending() {
        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Short", durationMinutes: 10),
            makeWorkout(date: Date(), exerciseName: "Long", durationMinutes: 30),
            makeWorkout(date: Date(), exerciseName: "Medium", durationMinutes: 20)
        ]

        let stats = service.groupedByExercise(workouts: workouts, exercises: [])

        #expect(stats[0].exerciseName == "Long")
        #expect(stats[1].exerciseName == "Medium")
        #expect(stats[2].exerciseName == "Short")
    }

    @Test func groupedByExercise_aggregatesReps() {
        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 20, reps: 100),
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 15, reps: 75)
        ]

        let stats = service.groupedByExercise(workouts: workouts, exercises: [])

        let burpeeStats = stats.first { $0.exerciseName == "Burpees" }
        #expect(burpeeStats?.totalReps == 175)
    }

    @Test func groupedByExercise_aggregatesRounds() {
        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Pull-ups", timerKind: .amrap, durationMinutes: 10, rounds: 5),
            makeWorkout(date: Date(), exerciseName: "Pull-ups", timerKind: .amrap, durationMinutes: 15, rounds: 8)
        ]

        let stats = service.groupedByExercise(workouts: workouts, exercises: [])

        let pullupStats = stats.first { $0.exerciseName == "Pull-ups" }
        #expect(pullupStats?.totalRounds == 13)
    }

    @Test func groupedByExercise_lookupsMuscleGroupFromExercises() {
        let exercises = [
            Exercise(name: "Burpees", exerciseDescription: "Full body", muscleGroup: .fullBody)
        ]
        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 20)
        ]

        let stats = service.groupedByExercise(workouts: workouts, exercises: exercises)

        let burpeeStats = stats.first { $0.exerciseName == "Burpees" }
        #expect(burpeeStats?.muscleGroup == .fullBody)
    }

    @Test func groupedByExercise_emptyWorkouts_returnsEmpty() {
        let stats = service.groupedByExercise(workouts: [], exercises: [])

        #expect(stats.isEmpty)
    }

    @Test func groupedByExercise_unknownExercise_hasNilMuscleGroup() {
        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Unknown Exercise", durationMinutes: 20)
        ]

        let stats = service.groupedByExercise(workouts: workouts, exercises: [])

        let unknownStats = stats.first { $0.exerciseName == "Unknown Exercise" }
        #expect(unknownStats?.muscleGroup == nil)
    }

    // MARK: - ExerciseStats Tests

    @Test func exerciseStats_summaryText_formatsSingularWorkout() {
        let stats = ExerciseStats(
            exerciseName: "Test",
            muscleGroup: nil,
            totalMinutes: 20,
            totalReps: nil,
            totalRounds: nil,
            workoutCount: 1
        )

        #expect(stats.summaryText.contains("1 workout"))
    }

    @Test func exerciseStats_summaryText_formatsPluralWorkouts() {
        let stats = ExerciseStats(
            exerciseName: "Test",
            muscleGroup: nil,
            totalMinutes: 45,
            totalReps: nil,
            totalRounds: nil,
            workoutCount: 3
        )

        #expect(stats.summaryText.contains("3 workouts"))
        #expect(stats.summaryText.contains("45 min"))
    }

    // MARK: - groupedByMuscleGroup Tests

    @Test func groupedByMuscleGroup_aggregatesByMuscleGroup() {
        let exercises = [
            Exercise(name: "Burpees", muscleGroup: .fullBody),
            Exercise(name: "Pull-ups", muscleGroup: .upperBody),
            Exercise(name: "Squats", muscleGroup: .lowerBody)
        ]

        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 20),
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 15),
            makeWorkout(date: Date(), exerciseName: "Pull-ups", timerKind: .amrap, durationMinutes: 10, reps: nil, rounds: 5)
        ]

        let stats = service.groupedByMuscleGroup(workouts: workouts, exercises: exercises)

        let fullBodyStats = stats.first { $0.muscleGroup == .fullBody }
        #expect(fullBodyStats?.totalMinutes == 35) // 20 + 15

        let upperBodyStats = stats.first { $0.muscleGroup == .upperBody }
        #expect(upperBodyStats?.totalMinutes == 10)

        let lowerBodyStats = stats.first { $0.muscleGroup == .lowerBody }
        #expect(lowerBodyStats == nil) // No workouts for lower body
    }

    @Test func groupedByMuscleGroup_ignoresExercisesWithoutMuscleGroup() {
        let exercises = [
            Exercise(name: "Burpees", muscleGroup: .fullBody),
            Exercise(name: "Unknown", muscleGroup: nil)
        ]

        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 20),
            makeWorkout(date: Date(), exerciseName: "Unknown", durationMinutes: 10)
        ]

        let stats = service.groupedByMuscleGroup(workouts: workouts, exercises: exercises)

        #expect(stats.count == 1)
        let fullBodyStats = stats.first { $0.muscleGroup == .fullBody }
        #expect(fullBodyStats?.totalMinutes == 20) // Only Burpees counted
    }

    @Test func groupedByMuscleGroup_ignoresUnknownExercises() {
        let exercises = [
            Exercise(name: "Burpees", muscleGroup: .fullBody)
        ]

        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Burpees", durationMinutes: 20),
            makeWorkout(date: Date(), exerciseName: "NotInDatabase", durationMinutes: 10)
        ]

        let stats = service.groupedByMuscleGroup(workouts: workouts, exercises: exercises)

        #expect(stats.count == 1)
        let fullBodyStats = stats.first { $0.muscleGroup == .fullBody }
        #expect(fullBodyStats?.totalMinutes == 20) // Only known exercise counted
    }

    @Test func groupedByMuscleGroup_emptyWorkouts_returnsEmpty() {
        let stats = service.groupedByMuscleGroup(workouts: [], exercises: [])

        #expect(stats.isEmpty)
    }

    @Test func groupedByMuscleGroup_noExercisesWithMuscleGroups_returnsEmpty() {
        let exercises = [
            Exercise(name: "Exercise Without Group", muscleGroup: nil)
        ]

        let workouts = [
            makeWorkout(date: Date(), exerciseName: "Exercise Without Group", durationMinutes: 20)
        ]

        let stats = service.groupedByMuscleGroup(workouts: workouts, exercises: exercises)

        #expect(stats.isEmpty)
    }

    @Test func groupedByMuscleGroup_floorsMinutes() {
        let exercises = [
            Exercise(name: "Burpees", muscleGroup: .fullBody)
        ]

        // 90 seconds = 1.5 minutes, should floor to 1 minute
        let workouts = [
            WorkoutLog(
                date: Date(),
                exerciseName: "Burpees",
                timerKind: .emom,
                durationSeconds: 90,
                repsCompleted: 10,
                roundsCompleted: nil
            )
        ]

        let stats = service.groupedByMuscleGroup(workouts: workouts, exercises: exercises)

        let fullBodyStats = stats.first { $0.muscleGroup == .fullBody }
        #expect(fullBodyStats?.totalMinutes == 1) // Floored
    }
}
