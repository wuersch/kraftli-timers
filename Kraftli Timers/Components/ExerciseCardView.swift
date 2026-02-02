//
//  ExerciseCardView.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// An expandable card for displaying exercise details in a selection list.
///
/// **Collapsed state**: Shows exercise name with info button to expand.
/// **Expanded state**: Shows name, description, muscle group tag, and difficulty indicator.
///
/// ## Interaction Model
/// - Tap anywhere on the card to select the exercise
/// - Tap the info button to expand/collapse details
/// - When expanded, a "Select" button provides clear call-to-action
struct ExerciseCardView: View {
    let exercise: ExerciseInfo
    let isExpanded: Bool
    let onSelect: () -> Void
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: always visible
            headerRow

            // Expanded content
            if isExpanded {
                expandedContent
                    .padding(.top, 12)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isExpanded ? Color(.systemGray6) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                onSelect()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(exercise.name)
        .accessibilityHint(isExpanded ? "Tap Select to choose this exercise" : "Tap to select, or tap info to see details")
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text(exercise.name)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            // Info button to toggle expand
            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isExpanded ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse details" : "Show details")
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Description
            Text(exercise.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Tags row
            HStack(spacing: 12) {
                MuscleGroupTag(muscleGroup: exercise.muscleGroup, size: .regular)

                if let difficulty = exercise.difficulty {
                    DifficultyIndicator(difficulty: difficulty, style: .pill)
                }

                Spacer()
            }

            // Select button
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Select")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    ExerciseRepository.load()

    return ScrollView {
        VStack(spacing: 16) {
            Text("Collapsed Card")
                .font(.caption)
                .foregroundStyle(.secondary)

            ExerciseCardView(
                exercise: ExerciseInfo(
                    name: "Burpees",
                    description: "Explosive movement combining squat, plank, push-up, and vertical jump.",
                    formTips: ["Keep core tight", "Land softly"],
                    muscleGroup: .fullBody,
                    difficulty: .intermediate
                ),
                isExpanded: false,
                onSelect: {},
                onToggleExpand: {}
            )

            Text("Expanded Card")
                .font(.caption)
                .foregroundStyle(.secondary)

            ExerciseCardView(
                exercise: ExerciseInfo(
                    name: "Push-ups",
                    description: "Classic upper body exercise pushing body up from floor. Builds chest, shoulder, and tricep strength while engaging core for stability.",
                    formTips: ["Hands shoulder-width apart", "Body forms straight line"],
                    muscleGroup: .upperBody,
                    difficulty: .beginner
                ),
                isExpanded: true,
                onSelect: {},
                onToggleExpand: {}
            )

            Text("Minimal Data Card")
                .font(.caption)
                .foregroundStyle(.secondary)

            ExerciseCardView(
                exercise: ExerciseInfo(
                    name: "Custom Exercise",
                    description: "A custom exercise with minimal configuration.",
                    formTips: [],
                    muscleGroup: .fullBody
                ),
                isExpanded: true,
                onSelect: {},
                onToggleExpand: {}
            )
        }
        .padding()
    }
}
