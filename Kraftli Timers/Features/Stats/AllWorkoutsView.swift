//
//  AllWorkoutsView.swift
//  Kraftli Timers
//
//  Standalone view for the global workout list with edit/delete functionality.
//

import SwiftData
import SwiftUI

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
                .cardListRow()
            }
            .onDelete(perform: deleteWorkouts)
        }
        .cardListStyle(isEmpty: workouts.isEmpty)
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

#Preview {
    NavigationStack {
        AllWorkoutsView()
    }
    .modelContainer(for: WorkoutLog.self, inMemory: true)
}
