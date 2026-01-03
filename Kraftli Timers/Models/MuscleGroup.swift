//
//  MuscleGroup.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 02.01.2026.
//

/// Target muscle group for an exercise.
enum MuscleGroup: String, Codable, CaseIterable {
    case fullBody
    case upperBody
    case lowerBody
    case core

    /// Human-readable display name for UI.
    var displayName: String {
        switch self {
        case .fullBody: return "Full Body"
        case .upperBody: return "Upper Body"
        case .lowerBody: return "Lower Body"
        case .core: return "Core"
        }
    }
}
