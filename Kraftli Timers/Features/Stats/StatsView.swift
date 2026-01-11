//
//  StatsView.swift
//  Kraftli Timers
//
//  Main stats dashboard showing workout statistics.
//

import SwiftUI
import SwiftData
import Charts

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

    // MARK: - Chart Section
    @ViewBuilder
    private var chartSection: some View {
        if !chartData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity")
                    .font(.headline)

                Chart(chartData) { dataPoint in
                    BarMark(
                        x: .value("Date", dataPoint.date, unit: selectedPeriod.chartUnit),
                        y: .value("Minutes", dataPoint.minutes)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    if selectedPeriod == .month {
                        // Use automatic spacing for month (too many days to show all)
                        AxisMarks(values: .automatic) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(xAxisLabel(for: date))
                                        .font(.caption2)
                                }
                            }
                        }
                    } else {
                        // Show all labels for week (7 days) and year (12 months)
                        AxisMarks(values: chartData.map(\.date)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(xAxisLabel(for: date))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let minutes = value.as(Int.self) {
                                Text("\(minutes)m")
                            }
                        }
                    }
                }
                .frame(height: 200)
                .accessibilityLabel("Activity chart showing \(totalMinutes) total minutes across \(chartData.count) \(selectedPeriod == .year ? "months" : "days")")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: - Chart Helpers

    /// Formats date for x-axis labels based on the selected period.
    /// - Week: Mon, Tue, Wed, etc.
    /// - Month: Day numbers (1, 8, 15, 22, 29)
    /// - Year: Single letter month (J, F, M, A, M, J, J, A, S, O, N, D)
    private func xAxisLabel(for date: Date) -> String {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .week:
            // Short weekday: Mon, Tue, Wed, etc.
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)

        case .month:
            // Day of month: 1, 8, 15, etc.
            let day = calendar.component(.day, from: date)
            return "\(day)"

        case .year:
            // Single letter month: J, F, M, etc.
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMMM" // Single letter month
            return formatter.string(from: date)
        }
    }
}

// MARK: - Summary Card
private struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - TimePeriod Chart Extensions
extension TimePeriod {
    var chartUnit: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .day
        case .year: return .month
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
