//
//  MuscleGroupCard.swift
//  Kraftli Timers
//
//  Displays muscle group time statistics in a 2x2 grid.
//

import SwiftUI

/// Card displaying total time per muscle group in a 2x2 grid layout.
struct MuscleGroupCard: View {
    let stats: [MuscleGroupStats]

    /// Lookup dictionary for O(1) access to stats by muscle group.
    private var statsByGroup: [MuscleGroup: Int] {
        Dictionary(uniqueKeysWithValues: stats.map { ($0.muscleGroup, $0.totalMinutes) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Groups")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    MuscleGroupCell(
                        muscleGroup: group,
                        totalMinutes: statsByGroup[group] ?? 0
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Muscle Group Cell

/// Individual cell displaying a single muscle group's statistics.
private struct MuscleGroupCell: View {
    let muscleGroup: MuscleGroup
    let totalMinutes: Int

    /// Formatted time string (floored): "X hr" or "X min".
    private var formattedTime: String {
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            return "\(hours) hr"
        } else {
            return "\(totalMinutes) min"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(muscleGroup.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formattedTime)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(muscleGroup.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // With varied data
        MuscleGroupCard(stats: [
            MuscleGroupStats(muscleGroup: .fullBody, totalMinutes: 120),
            MuscleGroupStats(muscleGroup: .upperBody, totalMinutes: 75),
            MuscleGroupStats(muscleGroup: .lowerBody, totalMinutes: 45),
            MuscleGroupStats(muscleGroup: .core, totalMinutes: 30)
        ])

        // All zeros
        MuscleGroupCard(stats: [
            MuscleGroupStats(muscleGroup: .fullBody, totalMinutes: 0),
            MuscleGroupStats(muscleGroup: .upperBody, totalMinutes: 0),
            MuscleGroupStats(muscleGroup: .lowerBody, totalMinutes: 0),
            MuscleGroupStats(muscleGroup: .core, totalMinutes: 0)
        ])

        // Empty stats (all show 0)
        MuscleGroupCard(stats: [])
    }
    .padding()
}
