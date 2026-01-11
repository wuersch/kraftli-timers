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
    let workouts: [WorkoutLog]
    let title: String

    @State private var activeSheet: WorkoutActiveSheet?

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
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(workouts.isEmpty)
        .background(Color(.systemBackground))
    }
}

// MARK: - All Workouts View (Editable)
/// Standalone view for the global workout list with edit/delete functionality.
/// Uses the same edit mode pattern as TimerPresetView.
struct AllWorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutLog.date, order: .reverse) private var workouts: [WorkoutLog]

    @State private var editMode: EditMode = .inactive
    @State private var activeSheet: WorkoutActiveSheet?

    var body: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRow(workout: workout) { tappedWorkout in
                    activeSheet = .edit(tappedWorkout)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
                )
            }
            .onDelete(perform: deleteWorkouts)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(workouts.isEmpty)
        .background(Color(.systemBackground))
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

struct WorkoutRow: View {
    let workout: WorkoutLog
    var didTapEdit: ((WorkoutLog) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workout.exerciseName)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                Pill(text: workout.timerKind.rawValue, color: workout.timerKind.color, fontSize: 11)
            }

            Text("\(workout.formattedDate)\(UISeparator.dot)\(workout.summaryText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            didTapEdit?(workout)
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

#Preview("All Workouts (Editable)") {
    NavigationStack {
        AllWorkoutsView()
    }
    .modelContainer(for: WorkoutLog.self, inMemory: true)
}
