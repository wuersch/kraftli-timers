//
//  TimerBottomSection.swift
//  Kraftli Timers
//
//  Bottom section of timer views showing total time and "Get ready" text.
//

import SwiftUI

/// Bottom section of timer views displaying the workout's overall time.
///
/// Shows "TOTAL" with the time remaining during normal operation (or, with `countsUp`,
/// "ELAPSED" with the time so far), and a pulsing "Get ready" message during countdown.
///
/// ## Usage
/// ```swift
/// TimerBottomSection(
///     time: timerModel.totalTimeRemaining,
///     isWaitingToStart: isWaitingToStart,
///     sizes: sizes
/// )
/// ```
struct TimerBottomSection: View {
    /// Time remaining, or the elapsed time when `countsUp`.
    let time: TimeInterval
    /// True until the workout starts running (waiting for the Watch, or counting down):
    /// shows the pulsing "get ready" text in place of the time.
    let isWaitingToStart: Bool
    let sizes: TimerSizes
    var isCompleted: Bool = false
    var totalDuration: TimeInterval = 0
    /// For an open-ended workout: shows the elapsed time, and the finish time once completed.
    var countsUp: Bool = false
    /// Shows a small Watch-slash icon while changes haven't reached the Watch yet.
    var showsWatchDisconnected: Bool = false

    /// Drives the "get ready" pulse. Private: only this view starts and stops it.
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Normal TOTAL section (always present for layout)
            VStack(spacing: 8) {
                Text(label)
                    .font(.system(size: sizes.labelFont))
                    .foregroundStyle(.gray)

                Text(displayedTime.formatted)
                    .font(.system(size: sizes.totalFont, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityValue(displayedTime.formatted)
                    // An overlay, so the icon doesn't shift the centered time.
                    .overlay(alignment: .trailing) {
                        if showsWatchDisconnected {
                            Image(systemName: "applewatch.slash")
                                .font(.system(size: sizes.labelFont))
                                .foregroundStyle(.gray)
                                .alignmentGuide(.trailing) { $0[.leading] - 8 }
                                .transition(.opacity)
                                .accessibilityLabel("Watch disconnected")
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: showsWatchDisconnected)
            }
            .opacity(isWaitingToStart ? 0 : 1)

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
                .opacity(isWaitingToStart ? 1 : 0)
                .onChange(of: isWaitingToStart) { _, newValue in
                    isPulsing = newValue
                }
        }
    }

    private var label: String {
        switch (countsUp, isCompleted) {
        case (false, false): "TOTAL"
        case (false, true): "DURATION"
        case (true, false): "ELAPSED"
        case (true, true): "FINISH TIME"
        }
    }

    private var accessibilityLabel: String {
        switch (countsUp, isCompleted) {
        case (false, false): "Total time"
        case (false, true): "Workout duration"
        case (true, false): "Elapsed time"
        case (true, true): "Finish time"
        }
    }

    /// A completed time-boxed workout shows its duration; otherwise the time as given.
    private var displayedTime: TimeInterval {
        isCompleted && !countsUp ? totalDuration : time
    }
}

// MARK: - Preview

#Preview("Timer Bottom Section") {
    VStack(spacing: 40) {
        TimerBottomSection(
            time: 125,
            isWaitingToStart: false,
            sizes: TimerSizes.emom(for: CGSize(width: 393, height: 852))
        )

        TimerBottomSection(
            time: 125,
            isWaitingToStart: true,
            sizes: TimerSizes.emom(for: CGSize(width: 393, height: 852))
        )

        TimerBottomSection(
            time: 0,
            isWaitingToStart: false,
            sizes: TimerSizes.emom(for: CGSize(width: 393, height: 852)),
            isCompleted: true,
            totalDuration: 1200
        )
    }
}
