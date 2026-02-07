//
//  TimerBottomSection.swift
//  Kraftli Timers
//
//  Bottom section of timer views showing total time and "Get ready" text.
//

import SwiftUI

/// Bottom section of timer views displaying total time remaining.
///
/// Shows the "TOTAL" label with countdown time during normal operation,
/// and a pulsing "Get ready" message during countdown.
///
/// ## Usage
/// ```swift
/// TimerBottomSection(
///     totalTimeRemaining: timerModel.totalTimeRemaining,
///     isCountingDown: countdown.isCountingDown,
///     isPulsing: $isPulsing,
///     sizes: sizes
/// )
/// ```
struct TimerBottomSection: View {
    let totalTimeRemaining: TimeInterval
    let isCountingDown: Bool
    @Binding var isPulsing: Bool
    let sizes: TimerSizes
    var isCompleted: Bool = false
    var totalDuration: TimeInterval = 0

    var body: some View {
        ZStack {
            // Normal TOTAL section (always present for layout)
            VStack(spacing: 8) {
                Text(isCompleted ? "DURATION" : "TOTAL")
                    .font(.system(size: sizes.labelFont))
                    .foregroundStyle(.gray)

                Text(isCompleted ? totalDuration.formatted : totalTimeRemaining.formatted)
                    .font(.system(size: sizes.totalFont, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .accessibilityLabel(isCompleted ? "Workout duration" : "Total time")
                    .accessibilityValue(isCompleted ? totalDuration.formatted : totalTimeRemaining.formatted)
            }
            .opacity(isCountingDown ? 0 : 1)

            // "Get ready" text (shown during countdown)
            Text("Get ready")
                .font(.system(size: sizes.totalFont * 0.5, weight: .medium))
                .foregroundStyle(.primary)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
                .opacity(isPulsing ? 1.0 : 0.6)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .padding(.top, sizes.spacing * 0.4)
                .opacity(isCountingDown ? 1 : 0)
                .onChange(of: isCountingDown) { _, newValue in
                    isPulsing = newValue
                }
        }
    }
}

// MARK: - Preview

#Preview("Timer Bottom Section") {
    VStack(spacing: 40) {
        TimerBottomSection(
            totalTimeRemaining: 125,
            isCountingDown: false,
            isPulsing: .constant(false),
            sizes: TimerSizes.emom(for: CGSize(width: 393, height: 852))
        )

        TimerBottomSection(
            totalTimeRemaining: 125,
            isCountingDown: true,
            isPulsing: .constant(true),
            sizes: TimerSizes.emom(for: CGSize(width: 393, height: 852))
        )

        TimerBottomSection(
            totalTimeRemaining: 0,
            isCountingDown: false,
            isPulsing: .constant(false),
            sizes: TimerSizes.emom(for: CGSize(width: 393, height: 852)),
            isCompleted: true,
            totalDuration: 1200
        )
    }
}
