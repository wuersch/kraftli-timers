//
//  Pill.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// A reusable pill-shaped tag component.
///
/// Displays text inside a colored capsule with a subtle fill and stroke.
/// Used as the base component for `MuscleGroupTag` and `DifficultyIndicator`.
///
/// ## Example
/// ```swift
/// Pill(text: "Beginner", color: .green)
/// Pill(text: "Full Body", color: .blue, fontSize: 14)
/// ```
struct Pill: View {
    let text: String
    let color: Color
    var fontSize: CGFloat = 12

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(color)
            .padding(.vertical, fontSize * 0.3)
            .padding(.horizontal, fontSize * 0.6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Basic Pills")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 8) {
            Pill(text: "Blue", color: .blue)
            Pill(text: "Green", color: .green)
            Pill(text: "Orange", color: .orange)
            Pill(text: "Red", color: .red)
        }

        Text("Different Sizes")
            .font(.caption)
            .foregroundStyle(.secondary)

        VStack(spacing: 8) {
            Pill(text: "Small (10pt)", color: .purple, fontSize: 10)
            Pill(text: "Regular (12pt)", color: .purple, fontSize: 12)
            Pill(text: "Large (14pt)", color: .purple, fontSize: 14)
        }
    }
    .padding()
}
