//
//  ExerciseSelectionView.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// A full-screen view for browsing and selecting an exercise.
///
/// Features:
/// - Scrollable list of expandable exercise cards
/// - Filter sheet for muscle group and difficulty
/// - Tap-to-select with immediate dismiss
/// - Empty state when no exercises match filters
///
/// ## Data Flow
/// 1. Exercises loaded from `ExerciseRepository` (in-memory reference data)
/// 2. Filtered in-memory based on user-selected criteria
/// 3. Selection updates the bound `selectedExerciseId`
/// 4. View dismisses automatically after selection
struct ExerciseSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    /// Binding to the selected exercise ID (updated on selection).
    @Binding var selectedExerciseId: UUID?

    // MARK: - Filter State

    @State private var muscleGroupFilter: MuscleGroup? = nil
    @State private var difficultyFilter: Difficulty? = nil
    @State private var showingFilters = false

    // MARK: - UI State

    /// ID of the currently expanded exercise card (only one at a time).
    @State private var expandedExerciseId: UUID? = nil

    /// Cached filtered exercises, updated when filters change.
    @State private var filteredExercises: [ExerciseInfo] = []

    /// True if any filter is active.
    private var hasActiveFilters: Bool {
        muscleGroupFilter != nil || difficultyFilter != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if filteredExercises.isEmpty {
                    emptyState
                } else {
                    exerciseList
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilters = true }) {
                        Image(
                            systemName: hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityLabel("Filter exercises")
                }
            }
            .sheet(isPresented: $showingFilters) {
                ExerciseFilterSheet(
                    muscleGroup: $muscleGroupFilter,
                    difficulty: $difficultyFilter
                )
            }
            .onAppear {
                updateFilteredExercises()
            }
            .onChange(of: muscleGroupFilter) {
                updateFilteredExercises()
            }
            .onChange(of: difficultyFilter) {
                updateFilteredExercises()
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredExercises) { exercise in
                    ExerciseCardView(
                        exercise: exercise,
                        isExpanded: expandedExerciseId == exercise.id,
                        onSelect: { selectExercise(exercise) },
                        onToggleExpand: { toggleExpand(exercise.id) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Exercises Found", systemImage: "figure.run")
        } description: {
            if hasActiveFilters {
                Text("No exercises match your current filters.")
            } else {
                Text("No exercises available.")
            }
        } actions: {
            if hasActiveFilters {
                Button("Clear Filters") {
                    muscleGroupFilter = nil
                    difficultyFilter = nil
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Actions

    private func selectExercise(_ exercise: ExerciseInfo) {
        selectedExerciseId = exercise.id
        dismiss()
    }

    private func toggleExpand(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedExerciseId == id {
                expandedExerciseId = nil
            } else {
                expandedExerciseId = id
            }
        }
    }

    private func updateFilteredExercises() {
        filteredExercises = ExerciseRepository.all.filter { exercise in
            let matchesMuscle = muscleGroupFilter == nil
                || exercise.muscleGroup == muscleGroupFilter
            let matchesDifficulty = difficultyFilter == nil
                || exercise.difficulty == difficultyFilter
            return matchesMuscle && matchesDifficulty
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedId: UUID? = nil

        var body: some View {
            ExerciseSelectionView(selectedExerciseId: $selectedId)
                .onAppear { ExerciseRepository.load() }
        }
    }

    return PreviewWrapper()
}
