//
//  WorkoutLogEditorView.swift
//  Kraftli Timers
//
//  Editor sheet for modifying workout log metrics.
//

import SwiftUI

/// A minimal editor for workout logs.
///
/// Displays read-only workout metadata (date, exercise, duration, timer kind)
/// with an editable picker for the relevant metric based on timer type:
/// - EMOM: reps completed
/// - AMRAP: rounds completed
struct WorkoutLogEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutLog

    @State private var editableValue: Int

    init(workout: WorkoutLog) {
        self.workout = workout
        let initialValue: Int
        switch workout.timerKind {
        case .emom:
            initialValue = workout.repsCompleted ?? 0
        case .amrap:
            initialValue = workout.roundsCompleted ?? 0
        }
        _editableValue = State(initialValue: initialValue)
    }

    // MARK: - Computed Properties

    private var metricLabel: String {
        switch workout.timerKind {
        case .emom: return "Reps Completed"
        case .amrap: return "Rounds Completed"
        }
    }

    private var metricRange: ClosedRange<Int> {
        switch workout.timerKind {
        case .emom: return 1...999
        case .amrap: return 1...99
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                readOnlySection
                editableSection
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveChanges()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save changes")
                }
            }
        }
    }

    // MARK: - Sections

    private var readOnlySection: some View {
        Section {
            ReadOnlyRow(label: "Date", value: workout.formattedDate)
            ReadOnlyRow(label: "Time", value: workout.formattedTime)
            ReadOnlyRow(label: "Exercise", value: workout.exerciseName)
            ReadOnlyRow(label: "Duration", value: "\(workout.durationMinutes) min")
            ReadOnlyRow(label: "Type", value: workout.timerKind.rawValue)
        }
    }

    private var editableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(metricLabel)
                    .font(.body)
                    .foregroundStyle(.primary)

                Picker(metricLabel, selection: $editableValue) {
                    ForEach(metricRange, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        switch workout.timerKind {
        case .emom:
            workout.repsCompleted = editableValue
        case .amrap:
            workout.roundsCompleted = editableValue
        }
        dismiss()
    }
}

// MARK: - Read-Only Row

private struct ReadOnlyRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("EMOM Workout") {
    WorkoutLogEditorView(
        workout: WorkoutLog(
            exerciseName: "6-Count Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )
    )
}

#Preview("AMRAP Workout") {
    WorkoutLogEditorView(
        workout: WorkoutLog(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 900,
            roundsCompleted: 15
        )
    )
}
