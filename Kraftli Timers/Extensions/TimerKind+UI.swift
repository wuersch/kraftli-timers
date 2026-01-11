//
//  TimerKind+UI.swift
//  Kraftli Timers
//
//  UI-specific extensions for TimerKind.
//

import SwiftUI

extension TimerKind {
    /// Accent color for timer kind display.
    /// Matches the colors used in timer views (EMOM=blue, AMRAP=indigo).
    var color: Color {
        switch self {
        case .emom: return .blue
        case .amrap: return .indigo
        }
    }
}
