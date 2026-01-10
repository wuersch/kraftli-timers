//
//  ExerciseStatsCard.swift
//  Kraftli Timers
//
//  Displays stats for a single exercise.
//

import SwiftUI

struct ExerciseStatsCard: View {
    let stats: ExerciseStats

    var body: some View {
        HStack(spacing: 12) {
            // Muscle group indicator (decorative)
            Image(systemName: "figure.run.square.stack")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundStyle(muscleGroupColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stats.exerciseName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 4) {
                    Text(stats.summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let reps = stats.totalReps {
                        Text("\(UISeparator.dot)\(reps) reps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let rounds = stats.totalRounds {
                        Text("\(UISeparator.dot)\(rounds) rounds")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view workouts")
    }

    private var accessibilityLabel: String {
        var label = "\(stats.exerciseName), \(stats.totalMinutes) minutes, \(stats.workoutCount) workout\(stats.workoutCount == 1 ? "" : "s")"
        if let reps = stats.totalReps {
            label += ", \(reps) reps"
        }
        if let rounds = stats.totalRounds {
            label += ", \(rounds) rounds"
        }
        return label
    }

    private var muscleGroupColor: Color {
        stats.muscleGroup?.color ?? .gray
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        ExerciseStatsCard(stats: ExerciseStats(
            exerciseName: "6-Count Burpees",
            muscleGroup: .fullBody,
            totalMinutes: 45,
            totalReps: 150,
            totalRounds: nil,
            workoutCount: 3
        ))

        ExerciseStatsCard(stats: ExerciseStats(
            exerciseName: "Pull-ups",
            muscleGroup: .upperBody,
            totalMinutes: 30,
            totalReps: nil,
            totalRounds: 45,
            workoutCount: 2
        ))

        ExerciseStatsCard(stats: ExerciseStats(
            exerciseName: "Unknown Exercise",
            muscleGroup: nil,
            totalMinutes: 20,
            totalReps: nil,
            totalRounds: nil,
            workoutCount: 1
        ))
    }
    .padding()
}
