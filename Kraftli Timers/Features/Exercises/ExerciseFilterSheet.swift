//
//  ExerciseFilterSheet.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// A filter sheet presented as a half-height modal.
///
/// Uses Form with inline pickers to let users filter exercises by:
/// - Muscle group (Full Body, Upper Body, Lower Body, Core, or All)
/// - Difficulty (Beginner, Intermediate, Advanced, or All)
///
/// ## SwiftUI Concepts
/// - `.presentationDetents([.medium])` controls sheet height
/// - `nil` represents "All" (no filter) using optional enum binding
/// - Inline picker style shows all options without navigation
struct ExerciseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var muscleGroup: MuscleGroup?
    @Binding var difficulty: Difficulty?

    /// True if any filter is active.
    private var hasActiveFilters: Bool {
        muscleGroup != nil || difficulty != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        Text("All").tag(nil as MuscleGroup?)
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.displayName).tag(group as MuscleGroup?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Muscle Group")
                }

                Section {
                    Picker("Difficulty", selection: $difficulty) {
                        Text("All").tag(nil as Difficulty?)
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            HStack {
                                Circle()
                                    .fill(level.color)
                                    .frame(width: 8, height: 8)
                                Text(level.displayName)
                            }
                            .tag(level as Difficulty?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Difficulty")
                }
            }
            .navigationTitle("Filter Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        muscleGroup = nil
                        difficulty = nil
                    }
                    .disabled(!hasActiveFilters)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var muscleGroup: MuscleGroup? = nil
        @State private var difficulty: Difficulty? = nil

        var body: some View {
            ExerciseFilterSheet(
                muscleGroup: $muscleGroup,
                difficulty: $difficulty
            )
        }
    }

    return PreviewWrapper()
}
