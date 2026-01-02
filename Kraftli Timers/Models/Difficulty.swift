//
//  Difficulty.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 02.01.2026.
//

enum Difficulty: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced

    /// Human-readable display name for UI
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}
