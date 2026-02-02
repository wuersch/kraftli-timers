//
//  WatchExerciseListView.swift
//  Kraftli Timers Watch App
//
//  Simple exercise picker for watchOS.
//  Tap to select an exercise and dismiss.
//

import SwiftUI

/// A simple scrollable list of exercises for selection.
///
/// Displays exercise name and muscle group. Tapping an exercise
/// updates the binding and dismisses the view.
struct WatchExerciseListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExerciseId: UUID?

    private var exercises: [ExerciseInfo] {
        ExerciseRepository.all
    }

    var body: some View {
        Group {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "figure.run",
                    description: Text("Exercises load from bundled data.")
                )
            } else {
                List {
                    ForEach(exercises) { exercise in
                        Button {
                            selectedExerciseId = exercise.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text(exercise.muscleGroup.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedExerciseId == exercise.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedId: UUID?

        var body: some View {
            NavigationStack {
                WatchExerciseListView(selectedExerciseId: $selectedId)
            }
            .onAppear { ExerciseRepository.load() }
        }
    }

    return PreviewWrapper()
}
