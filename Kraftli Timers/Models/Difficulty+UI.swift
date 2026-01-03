//
//  Difficulty+UI.swift
//  Kraftli Timers
//
//  Created by Claude on 03.01.2026.
//

import SwiftUI

/// UI-specific extensions for Difficulty.
/// Separated from the domain model to keep it free of SwiftUI dependencies.
extension Difficulty {
    /// Traffic light color convention for difficulty indication.
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}
