//
//  MuscleGroupCard.swift
//  Kraftli Timers
//
//  Displays muscle group time statistics in a 2x2 grid.
//

import SwiftUI

struct MuscleGroupCard: View {
    let stats: [MuscleGroupStats]
    
    @ScaledMetric(relativeTo: .headline) private var dividerHeight: CGFloat = 34

    /// Lookup dictionary for O(1) access to stats by muscle group.
    private var statsByGroup: [MuscleGroup: Int] {
        Dictionary(uniqueKeysWithValues: stats.map { ($0.muscleGroup, $0.totalMinutes) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("Muscle Groups", systemImage: "figure.cross.training.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 0) {
                ForEach(Array(MuscleGroup.allCases.enumerated()), id: \.element) { index, group in
                    MuscleGroupColumn(
                        muscleGroup: group,
                        totalMinutes: statsByGroup[group] ?? 0
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if index < MuscleGroup.allCases.count - 1 {
                        Divider()
                            .frame(height: dividerHeight)
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .padding()
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Muscle Group Column and Cell

/// Individual cell displaying a single muscle group's statistics.
private struct MuscleGroupColumn: View {
    let muscleGroup: MuscleGroup
    let totalMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(muscleGroup.shortDisplayName)
                .font(.caption)
                .foregroundStyle(muscleGroup.color)

            TimeCell(totalMinutes: totalMinutes)
        }
    }
}

private struct TimeCell: View {
    let totalMinutes: Int
    
    var body : some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if totalMinutes >= 60 {
                Text("\(totalMinutes / 60)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("hr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(totalMinutes)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("min")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
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
