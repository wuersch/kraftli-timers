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

    @State private var selectedPeriod: TimePeriod = .week

    private let statsService: StatsService

    init(statsService: StatsService = DefaultStatsService()) {
        self.statsService = statsService
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
        // One snapshot per render: every section shows the same period as of the same "now".
        let stats = statsService.snapshot(
            of: allWorkouts,
            period: selectedPeriod,
            exercises: ExerciseRepository.all,
            referenceDate: Date()
        )

        return ScrollView {
            VStack(spacing: 16) {
                periodPicker
                summarySection(stats)
                MuscleGroupCard(stats: stats.muscleGroupStats)
                ActivityChart(
                    chartData: stats.chartData,
                    selectedPeriod: selectedPeriod,
                    totalMinutes: stats.totalMinutes // Used in accessibility description
                )
                allWorkoutsLink
                exercisesSection(stats)
            }
            .padding()
        }
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        Picker("Time Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.selectableCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Section
    private func summarySection(_ stats: StatsSnapshot) -> some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Total Time",
                value: "\(stats.totalMinutes)",
                unit: "min",
                systemImage: "clock.fill",
                iconColor: .teal
            )

            SummaryCard(
                title: "Workouts",
                value: "\(stats.workoutCount)",
                unit: selectedPeriod.summaryUnit,
                systemImage: "flame.fill",
                iconColor: .orange
            )
        }
    }

    // MARK: - All Workouts Link
    private var allWorkoutsLink: some View {
        NavigationLink {
            WorkoutListView(title: "All Workouts", emptyDescription: "Complete a workout to see it here")
        } label: {
            HStack {
                Label("All Workouts", systemImage: "list.bullet")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercises Section
    private func exercisesSection(_ stats: StatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Exercise")
                .font(.headline)

            if stats.exerciseStats.isEmpty {
                Text("No exercises in this period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(stats.exerciseStats) { stat in
                    NavigationLink {
                        WorkoutListView(
                            title: stat.exerciseName,
                            emptyDescription: "No workouts found for this selection",
                            exerciseName: stat.exerciseName,
                            since: stats.periodStart
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
    .modelContainer(for: WorkoutLog.self, inMemory: true)
    .onAppear { ExerciseRepository.load() }
}

// MARK: - Preview Container
@MainActor
private let previewContainer: ModelContainer = {
    // Load exercise repository for preview
    ExerciseRepository.load()

    let container = try! ModelContainer(
        for: WorkoutLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

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
