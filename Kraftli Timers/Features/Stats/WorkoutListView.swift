//
//  WorkoutListView.swift
//  Kraftli Timers
//
//  Displays a list of workout logs with optional editing.
//

import SwiftData
import SwiftUI

// MARK: - Sheet State

/// Sheet state for workout editing.
enum WorkoutActiveSheet: Identifiable {
    case edit(WorkoutLog)

    var id: String {
        switch self {
        case .edit(let workout): return workout.id.uuidString
        }
    }
}

// MARK: - Workout List View

struct WorkoutListView: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext

    let workouts: [WorkoutLog]
    let title: String

    @State private var activeSheet: WorkoutActiveSheet?
    @State private var editMode: EditMode = .inactive

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
                    .accessibilityLabel(
                        editMode == .active ? "Done editing" : "Edit workouts"
                    )
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit(let workout):
                WorkoutLogEditorView(workout: workout)
            }
        }
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
                WorkoutRow(workout: workout) { tappedWorkout in
                    activeSheet = .edit(tappedWorkout)
                }
                .cardListRow()
            }
            .onDelete(perform: deleteWorkouts)
        }
        .cardListStyle(isEmpty: workouts.isEmpty)
    }

    // MARK: - Actions

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

// MARK: - Preview
#Preview("With Workouts") {
    NavigationStack {
        WorkoutListView(
            workouts: [
                WorkoutLog(
                    exerciseName: "6-Count Burpees",
                    timerKind: .emom,
                    durationSeconds: 1200,
                    repsCompleted: 100,
                    roundsCompleted: nil
                ),
                WorkoutLog(
                    exerciseName: "Pull-ups",
                    timerKind: .amrap,
                    durationSeconds: 900,
                    repsCompleted: nil,
                    roundsCompleted: 15
                ),
                WorkoutLog(
                    exerciseName: "Squats",
                    timerKind: .amrap,
                    durationSeconds: 600,
                    repsCompleted: nil,
                    roundsCompleted: 30
                ),
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
