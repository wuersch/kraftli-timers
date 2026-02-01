//
//  CountdownText.swift
//  Kraftli Timers
//
//  Large countdown number display (3, 2, 1, GO) before timer starts.
//

import SwiftUI

/// Large countdown number display for timer countdown sequence.
///
/// Displays countdown values (3, 2, 1) and "GO" with smooth numeric transitions.
/// Used in the center of timer views during the pre-workout countdown.
///
/// ## Usage
/// ```swift
/// CountdownText(
///     countdownValue: countdown.countdownValue,
///     fontSize: sizes.primaryFont * 1.5
/// )
/// ```
struct CountdownText: View {
    /// Current countdown value: positive integers for countdown, 0 for "GO", nil hides the view.
    let countdownValue: Int?

    /// Font size for the countdown display.
    let fontSize: CGFloat

    var body: some View {
        let displayText = countdownValue.map { $0 > 0 ? "\($0)" : "GO" } ?? ""

        Text(displayText)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
            .id(countdownValue)
            .accessibilityLabel(displayText)
    }
}

// MARK: - Preview

#Preview("Countdown Text") {
    VStack(spacing: 40) {
        CountdownText(countdownValue: 3, fontSize: 80)
        CountdownText(countdownValue: 2, fontSize: 80)
        CountdownText(countdownValue: 1, fontSize: 80)
        CountdownText(countdownValue: 0, fontSize: 80)
    }
}
