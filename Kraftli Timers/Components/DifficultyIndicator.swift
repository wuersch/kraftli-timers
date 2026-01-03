//
//  DifficultyIndicator.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// A visual indicator for exercise difficulty level.
///
/// Colors follow traffic light convention:
/// - Beginner: Green (easy/go)
/// - Intermediate: Orange/Yellow (caution)
/// - Advanced: Red (stop and think)
///
/// Supports multiple display styles:
/// - `.dot`: Small colored circle, optionally with label
/// - `.pill`: Colored pill similar to MuscleGroupTag
struct DifficultyIndicator: View {
    let difficulty: Difficulty
    var style: Style = .dot
    var showLabel: Bool = true

    enum Style {
        case dot   // Small colored circle
        case pill  // Colored pill with text (like MuscleGroupTag)
    }

    var body: some View {
        switch style {
        case .dot:
            dotStyle
        case .pill:
            pillStyle
        }
    }

    // MARK: - Dot Style

    private var dotStyle: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            if showLabel {
                Text(difficulty.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(difficulty.displayName) difficulty")
    }

    // MARK: - Pill Style

    private var pillStyle: some View {
        Pill(
            text: difficulty.displayName,
            color: difficulty.color,
            fontSize: 11
        )
        .accessibilityLabel("\(difficulty.displayName) difficulty")
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Dot with Label")
            .font(.caption)
            .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 12) {
            ForEach(Difficulty.allCases, id: \.self) { level in
                DifficultyIndicator(difficulty: level, style: .dot, showLabel: true)
            }
        }

        Text("Dot Only")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 16) {
            ForEach(Difficulty.allCases, id: \.self) { level in
                DifficultyIndicator(difficulty: level, style: .dot, showLabel: false)
            }
        }

        Text("Pill Style")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 8) {
            ForEach(Difficulty.allCases, id: \.self) { level in
                DifficultyIndicator(difficulty: level, style: .pill)
            }
        }
    }
    .padding()
}
