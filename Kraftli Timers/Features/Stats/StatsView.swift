//
//  StatsView.swift
//  Kraftli Timers
//
//  Main stats dashboard showing workout statistics.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    // MARK: - Properties
    @Query(sort: \WorkoutLog.date, order: .reverse) private var allWorkouts: [WorkoutLog]
    @Query private var exercises: [Exercise]

    @State private var selectedPeriod: TimePeriod = .week

    private let statsService: StatsService = DefaultStatsService()

    // MARK: - Computed Properties
    private var filteredWorkouts: [WorkoutLog] {
        statsService.filterByPeriod(
            workouts: allWorkouts,
            period: selectedPeriod,
            referenceDate: Date()
        )
    }

    private var chartData: [ChartDataPoint] {
        statsService.totalMinutesPerDay(workouts: filteredWorkouts, period: selectedPeriod, referenceDate: Date())
    }

    private var exerciseStats: [ExerciseStats] {
        statsService.groupedByExercise(workouts: filteredWorkouts, exercises: exercises)
    }

    private var totalMinutes: Int {
        filteredWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }

    private var workoutCount: Int {
        filteredWorkouts.count
    }

    private var muscleGroupStats: [MuscleGroupStats] {
        statsService.groupedByMuscleGroup(workouts: filteredWorkouts, exercises: exercises)
    }

    // MARK: - Body
    var body: some View {
        Group {
            if allWorkouts.isEmpty {
                emptyStateView
            } else {
                statsContent
            }
        }
        .navigationTitle("Stats")
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Workouts Yet",
            systemImage: "chart.bar",
            description: Text("Complete a workout to see your stats")
        )
    }

    // MARK: - Stats Content
    private var statsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                summarySection
                muscleGroupSection
                chartSection
                allWorkoutsLink
                exercisesSection
            }
            .padding()
        }
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Section
    private var summarySection: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Total Time",
                value: "\(totalMinutes)",
                unit: "min",
                systemImage: "clock.fill",
                iconColor: .teal
            )

            SummaryCard(
                title: "Workouts",
                value: "\(workoutCount)",
                unit: selectedPeriod == .week ? "this week" : (selectedPeriod == .month ? "this month" : "this year"),
                systemImage: "flame.fill",
                iconColor: .orange
            )
        }
    }

    // MARK: - Muscle Group Section
    private var muscleGroupSection: some View {
        MuscleGroupCard(stats: muscleGroupStats)
    }

    // MARK: - Chart Section
    @ViewBuilder
    private var chartSection: some View {
        if !chartData.isEmpty {
            ActivityChart(
                chartData: chartData,
                selectedPeriod: selectedPeriod,
                totalMinutes: totalMinutes
            )
        }
    }

    // MARK: - All Workouts Link
    private var allWorkoutsLink: some View {
        NavigationLink {
            AllWorkoutsView()
        } label: {
            HStack {
                Label("All Workouts", systemImage: "list.bullet")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Exercise")
                .font(.headline)

            if exerciseStats.isEmpty {
                Text("No exercises in this period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(exerciseStats) { stat in
                    NavigationLink {
                        WorkoutListView(
                            workouts: filteredWorkouts.filter { $0.exerciseName == stat.exerciseName },
                            title: stat.exerciseName
                        )
                    } label: {
                        ExerciseStatsCard(stats: stat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

// MARK: - Preview
#Preview("With Data") {
    NavigationStack {
        StatsView()
    }
    .modelContainer(previewContainer)
}

#Preview("Empty State") {
    NavigationStack {
        StatsView()
    }
    .modelContainer(for: [WorkoutLog.self, Exercise.self], inMemory: true)
}

// MARK: - Preview Container
@MainActor
private let previewContainer: ModelContainer = {
    let container = try! ModelContainer(
        for: WorkoutLog.self, Exercise.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Add sample data
    let exercises = [
        Exercise(name: "6-Count Burpees", muscleGroup: .fullBody),
        Exercise(name: "Pull-ups", muscleGroup: .upperBody),
        Exercise(name: "Squats", muscleGroup: .lowerBody)
    ]
    exercises.forEach { container.mainContext.insert($0) }

    let calendar = Calendar.current
    let today = Date()

    // Sample workouts across the week
    let workouts = [
        WorkoutLog(exerciseName: "6-Count Burpees", timerKind: .emom, durationSeconds: 1200, repsCompleted: 100, roundsCompleted: nil),
        WorkoutLog(exerciseName: "Pull-ups", timerKind: .amrap, durationSeconds: 900, repsCompleted: nil, roundsCompleted: 15),
        WorkoutLog(exerciseName: "6-Count Burpees", timerKind: .emom, durationSeconds: 600, repsCompleted: 50, roundsCompleted: nil),
        WorkoutLog(exerciseName: "Squats", timerKind: .amrap, durationSeconds: 1200, repsCompleted: nil, roundsCompleted: 45)
    ]

    for (index, workout) in workouts.enumerated() {
        workout.date = calendar.date(byAdding: .day, value: -index, to: today) ?? today
        container.mainContext.insert(workout)
    }

    return container
}()
