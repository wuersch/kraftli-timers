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

    /// Asset name for the timer kind glyph (used as the top-left mark on the
    /// Watch active-workout screen, and in preset rows on iPhone).
    var icon: String {
        switch self {
        case .emom: return "timer.interval"
        case .amrap: return "timer.amrap"
        }
    }
}
