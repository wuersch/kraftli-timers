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
/// - EMOM, For Time: reps completed
/// - AMRAP: rounds completed
struct WorkoutLogEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutLog

    @State private var editableValue: Int

    init(workout: WorkoutLog) {
        self.workout = workout
        let storedValue: Int?
        switch workout.timerKind {
        case .emom, .forTime:
            storedValue = workout.repsCompleted
        case .amrap:
            storedValue = workout.roundsCompleted
        }
        // Start inside the picker's range, even for a log without a stored value.
        let range = Self.metricRange(for: workout.timerKind)
        _editableValue = State(initialValue: min(max(storedValue ?? range.lowerBound, range.lowerBound), range.upperBound))
    }

    // MARK: - Computed Properties

    private var metricLabel: String {
        switch workout.timerKind {
        case .emom, .forTime: return "Reps Completed"
        case .amrap: return "Rounds Completed"
        }
    }

    private var metricRange: ClosedRange<Int> {
        Self.metricRange(for: workout.timerKind)
    }

    private static func metricRange(for kind: TimerKind) -> ClosedRange<Int> {
        switch kind {
        case .emom, .forTime: return 1...999
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
            ReadOnlyRow(label: "Duration", value: workout.formattedDuration)
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
        case .emom, .forTime:
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
