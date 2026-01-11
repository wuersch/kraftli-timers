//
//  MuscleGroup+UI.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// UI-specific extensions for MuscleGroup.
/// Separated from the domain model to keep it free of SwiftUI dependencies.
extension MuscleGroup {
    /// Color for muscle group tag display.
    /// Uses colors distinct from Difficulty (green/orange/red traffic light).
    var color: Color {
        switch self {
        case .fullBody: return .blue
        case .upperBody: return .indigo
        case .lowerBody: return .teal
        case .core: return .purple
        }
    }
}
