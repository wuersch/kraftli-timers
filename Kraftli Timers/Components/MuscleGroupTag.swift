//
//  MuscleGroupTag.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// A type-safe pill tag for displaying muscle groups.
///
/// Wraps the generic `Pill` component with muscle group semantics.
/// Supports two sizes: `.regular` for selection views, `.compact` for inline display.
struct MuscleGroupTag: View {
    let muscleGroup: MuscleGroup
    var size: TagSize = .regular

    enum TagSize {
        case compact  // For inline display in editor
        case regular  // For selection view cards

        var fontSize: CGFloat {
            switch self {
            case .compact: return 11
            case .regular: return 12
            }
        }
    }

    var body: some View {
        Pill(
            text: muscleGroup.displayName,
            color: muscleGroup.color,
            fontSize: size.fontSize
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Regular Size")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 12) {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                MuscleGroupTag(muscleGroup: group, size: .regular)
            }
        }

        Text("Compact Size")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 8) {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                MuscleGroupTag(muscleGroup: group, size: .compact)
            }
        }
    }
    .padding()
}
