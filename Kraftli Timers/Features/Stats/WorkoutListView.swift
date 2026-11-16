//
//  WorkoutListView.swift
//  Kraftli Timers
//
//  Displays a list of workout logs with editing and deleting.
//

import SwiftData
import SwiftUI

/// A list of recorded workouts, newest first: all of them, or those of one exercise
/// since a given date.
///
/// ## SwiftUI: a query configured in `init`
/// The view fetches its own workouts with `@Query` instead of being handed an array.
/// A `@Query` is normally declared with fixed arguments; when the filter depends on the
/// view's parameters, it is built in `init` and assigned to the property wrapper's
/// storage (`_workouts`). Because the query is live, a deleted or edited workout
/// updates the list at once. An array passed in from the parent would be a snapshot
/// that still holds a workout after it was deleted.
struct WorkoutListView: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [WorkoutLog]

    private let title: String
    private let emptyDescription: String

    @State private var workoutToEdit: WorkoutLog?
    @State private var editMode: EditMode = .inactive

    /// - Parameters:
    ///   - title: The navigation title.
    ///   - emptyDescription: Shown when no workout matches.
    ///   - exerciseName: Only this exercise's workouts; nil for all exercises.
    ///   - start: Only workouts from this date on; nil for all time.
    init(
        title: String,
        emptyDescription: String,
        exerciseName: String? = nil,
        since start: Date? = nil
    ) {
        self.title = title
        self.emptyDescription = emptyDescription

        _workouts = Query(
            filter: Self.filter(exerciseName: exerciseName, since: start),
            sort: \.date,
            order: .reverse
        )
    }

    /// The workouts the list shows. A function of its own so tests can run the same
    /// predicate against a store: a `#Predicate` is only translated when it is used.
    static func filter(exerciseName: String?, since start: Date?) -> Predicate<WorkoutLog> {
        let start = start ?? .distantPast
        if let exerciseName {
            return #Predicate { $0.exerciseName == exerciseName && $0.date >= start }
        } else {
            return #Predicate { $0.date >= start }
        }
    }

    // MARK: - Body
    var body: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRow(workout: workout) { tappedWorkout in
                    workoutToEdit = tappedWorkout
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
                    description: Text(emptyDescription)
                )
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
        .sheet(item: $workoutToEdit) { workout in
            WorkoutLogEditorView(workout: workout)
        }
        .onChange(of: workouts.isEmpty) { _, isEmpty in
            if isEmpty {
                editMode = .inactive
            }
        }
    }

    // MARK: - Actions

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

// MARK: - Preview
#Preview("All Workouts") {
    NavigationStack {
        WorkoutListView(title: "All Workouts", emptyDescription: "Complete a workout to see it here")
    }
    .modelContainer(previewContainer)
}

#Preview("One Exercise") {
    NavigationStack {
        WorkoutListView(
            title: "Pull-ups",
            emptyDescription: "No workouts found for this selection",
            exerciseName: "Pull-ups"
        )
    }
    .modelContainer(previewContainer)
}

#Preview("Empty") {
    NavigationStack {
        WorkoutListView(title: "Workouts", emptyDescription: "No workouts found for this selection")
    }
    .modelContainer(for: WorkoutLog.self, inMemory: true)
}

@MainActor
private let previewContainer: ModelContainer = {
    let container = try! ModelContainer(
        for: WorkoutLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let workouts = [
        WorkoutLog(exerciseName: "6-Count Burpees", timerKind: .emom, durationSeconds: 1200, repsCompleted: 100),
        WorkoutLog(exerciseName: "Pull-ups", timerKind: .amrap, durationSeconds: 900, roundsCompleted: 15),
        WorkoutLog(exerciseName: "Squats", timerKind: .amrap, durationSeconds: 600, roundsCompleted: 30)
    ]
    workouts.forEach(container.mainContext.insert)
    return container
}()
