//
//  WorkoutListView.swift
//  Kraftli Timers
//
//  Displays a list of workout logs with optional editing.
//

import SwiftUI
import SwiftData

struct WorkoutListView: View {
    // MARK: - Properties
    let workouts: [WorkoutLog]
    let title: String

    // MARK: - Body
    var body: some View {
        Group {
            if workouts.isEmpty {
                emptyStateView
            } else {
                workoutList
            }
        }
        .navigationTitle(title)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Workouts",
            systemImage: "list.bullet",
            description: Text("No workouts found for this selection")
        )
    }

    // MARK: - Workout List
    private var workoutList: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRow(workout: workout)
            }
        }
    }
}

// MARK: - All Workouts View (Editable)
/// Standalone view for the global workout list with edit/delete functionality.
/// Uses the same edit mode pattern as TimerPresetView.
struct AllWorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLog.date, order: .reverse) private var workouts: [WorkoutLog]

    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRow(workout: workout)
            }
            .onDelete(perform: deleteWorkouts)
        }
        .overlay {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "list.bullet",
                    description: Text("Complete a workout to see it here")
                )
            }
        }
        .navigationTitle("All Workouts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !workouts.isEmpty {
                    Button {
                        withAnimation {
                            editMode = (editMode == .active) ? .inactive : .active
                        }
                    } label: {
                        Text(editMode == .active ? "Done" : "Edit")
                    }
                    .accessibilityLabel(editMode == .active ? "Done editing" : "Edit workouts")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: workouts.isEmpty) { _, isEmpty in
            if isEmpty {
                editMode = .inactive
            }
        }
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

// MARK: - Workout Row
private struct WorkoutRow: View {
    let workout: WorkoutLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workout.exerciseName)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                Text(workout.timerKind.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(workout.timerKind.color.opacity(0.2))
                    .foregroundStyle(workout.timerKind.color)
                    .clipShape(Capsule())
            }

            HStack {
                Text(workout.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(UISeparator.dot)
                    .foregroundStyle(.secondary)

                Text(workout.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("With Workouts") {
    NavigationStack {
        WorkoutListView(
            workouts: [
                WorkoutLog(exerciseName: "6-Count Burpees", timerKind: .emom, durationSeconds: 1200, repsCompleted: 100, roundsCompleted: nil),
                WorkoutLog(exerciseName: "Pull-ups", timerKind: .amrap, durationSeconds: 900, repsCompleted: nil, roundsCompleted: 15),
                WorkoutLog(exerciseName: "Squats", timerKind: .amrap, durationSeconds: 600, repsCompleted: nil, roundsCompleted: 30)
            ],
            title: "Recent Workouts"
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        WorkoutListView(workouts: [], title: "Workouts")
    }
}

#Preview("All Workouts (Editable)") {
    NavigationStack {
        AllWorkoutsView()
    }
    .modelContainer(for: WorkoutLog.self, inMemory: true)
}
