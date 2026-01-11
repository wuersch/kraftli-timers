//
//  SummaryCard.swift
//  Kraftli Timers
//
//  Displays a summary metric card with icon, value, and unit.
//

import SwiftUI

/// A card displaying a summary statistic with icon and value.
struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack(spacing: 16) {
        SummaryCard(
            title: "Total Time",
            value: "120",
            unit: "min",
            systemImage: "clock.fill",
            iconColor: .teal
        )

        SummaryCard(
            title: "Workouts",
            value: "5",
            unit: "this week",
            systemImage: "flame.fill",
            iconColor: .orange
        )
    }
    .padding()
}
