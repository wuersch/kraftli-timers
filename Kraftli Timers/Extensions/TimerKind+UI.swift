//
//  TimerKind+UI.swift
//  Kraftli Timers
//
//  UI-specific extensions for TimerKind.
//

import SwiftUI

extension TimerKind {
    /// Accent color of the kind, used by its timer screen and wherever the kind is shown.
    var color: Color {
        switch self {
        case .emom: return .blue
        case .amrap: return .indigo
        case .forTime: return .teal
        }
    }

    /// Asset name for the timer kind glyph (used as the top-left mark on the
    /// Watch active-workout screen, and in preset rows on iPhone).
    var icon: String {
        switch self {
        case .emom: return "timer.interval"
        case .amrap: return "timer.amrap"
        case .forTime: return "timer.simple"
        }
    }

    /// What a tap does while the workout is running.
    var runningTap: TimerRunningTap {
        switch self {
        case .emom: .pause
        case .amrap: .countRound
        case .forTime: .declareDone
        }
    }
}

/// What a tap does while a workout is running. (On the iPhone, a tap also starts a
/// workout that hasn't started and resumes a paused one, for every kind.)
enum TimerRunningTap {
    /// EMOM: pause. (The Watch pauses with its controls page instead.)
    case pause
    /// AMRAP: count a round.
    case countRound
    /// For Time: declare the workout done.
    case declareDone
}
