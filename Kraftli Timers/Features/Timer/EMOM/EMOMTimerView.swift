//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI

// MARK: - EMOMTimerView

/// The EMOM face of `TimerScreen`: an inner ring for the current interval, an outer ring
/// for the whole workout, and the interval time (or the rep count) in the center.
struct EMOMTimerView: View {
    @State private var timerModel: EMOMTimerModel
    private let link: TimerScreenLink

    /// When true, shows reps count prominently in center instead of interval countdown.
    private let showRepsInCenter: Bool

    init(
        timerModel: EMOMTimerModel = EMOMTimerModel(
            totalReps: 5,
            totalMinutes: 1,
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: DefaultFeedback()
        ),
        showRepsInCenter: Bool = false,
        link: TimerScreenLink = TimerScreenLink()
    ) {
        self.timerModel = timerModel
        self.showRepsInCenter = showRepsInCenter
        self.link = link
    }

    // MARK: - Styling
    private var isCompleted: Bool { timerModel.isCompleted }

    private var accentColor: Color {
        if isCompleted { return .green }
        return timerModel.isIntervalWarning ? .orange : TimerKind.emom.color
    }

    var body: some View {
        TimerScreen(
            model: timerModel,
            config: TimerConfig(
                kind: .emom,
                totalDuration: timerModel.totalDuration,
                intervalCount: timerModel.totalIntervals,
                exerciseName: link.exerciseName
            ),
            link: link,
            style: TimerScreenStyle(
                sizes: TimerSizes.emom(for:),
                color: TimerKind.emom.color,
                startingIconScale: 0.6,
                countdownScale: 1.5
            ),
            runningTap: .pause,
            holdTogglesPause: false,
            hintText: hintText,
            accessibilityLabel: isCompleted ? "Timer completed" : (timerModel.isRunning ? "Timer running" : "Timer paused"),
            accessibilityHint: isCompleted ? "Swipe down to close" : "\(hintText), swipe down to close",
            total: TimerScreenTotal(
                time: timerModel.totalTimeRemaining,
                totalDuration: timerModel.totalDuration
            )
        ) { context in
            rings(context)
        } center: { context in
            centerContent(context)
        }
    }

    // MARK: - Rings

    /// Both rings stay full during the countdown and fill on completion.
    @ViewBuilder
    private func rings(_ context: TimerScreenContext) -> some View {
        let isFull = context.isCompleted || context.isWaitingToStart

        ProgressRing(
            size: context.sizes.primaryRing,
            lineWidth: context.sizes.primaryLineWidth,
            progress: isFull ? 1.0 : timerModel.intervalProgress,
            color: accentColor,
            backgroundColor: Color.gray.opacity(0.2),
            rotationDegrees: -89.5
        )

        if let outerRing = context.sizes.secondaryRing, let outerLineWidth = context.sizes.secondaryLineWidth {
            ProgressRing(
                size: outerRing,
                lineWidth: outerLineWidth,
                progress: isFull ? 1.0 : timerModel.overallProgress,
                color: .primary,
                backgroundColor: Color.gray.opacity(0.2),
                rotationDegrees: -90.5
            )
        }
    }

    // MARK: - Helpers
    private func makeRepsText(accent: Color) -> AttributedString {
        var attr = AttributedString("\(timerModel.currentInterval)/\(timerModel.totalIntervals) REPS")
        attr.foregroundColor = .primary
        if let repsRange = attr.range(of: " REPS") {
            attr[repsRange].foregroundColor = accent
        }
        return attr
    }

    private var hintText: String {
        if !timerModel.isRunning && timerModel.overallProgress >= 1.0 {
            return "Tap to start"
        } else if timerModel.isRunning {
            return "Tap to pause"
        } else {
            return "Tap to resume"
        }
    }

    // MARK: - Center Content
    @ViewBuilder
    private func centerContent(_ context: TimerScreenContext) -> some View {
        let sizes = context.sizes
        VStack(spacing: 8) {
            Text(showRepsInCenter ? "REPS" : (isCompleted ? "INTERVALS" : "INTERVAL"))
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)

            if showRepsInCenter {
                // Reps-focused mode: show reps count prominently
                Text("\(timerModel.currentInterval)/\(timerModel.totalIntervals)")
                    .font(
                        .system(
                            size: sizes.primaryFont,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Reps completed")
                    .accessibilityValue(
                        "\(timerModel.currentInterval) of \(timerModel.totalIntervals)"
                    )

                // Third element for vertical balance
                if let visibleHint = context.visibleHint {
                    TimerHintLine(text: visibleHint, context: context, minimumScaleFactor: 0.9)
                } else {
                    // Small interval countdown as secondary info
                    Text(timerModel.intervalTimeRemaining.formatted)
                        .font(.system(size: sizes.labelFont, weight: .medium, design: .rounded))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .accessibilityLabel("Interval time remaining")
                        .accessibilityValue(timerModel.intervalTimeRemaining.formatted)
                }
            } else {
                // Interval-focused mode: show countdown, or completed intervals when done
                if isCompleted {
                    Text("\(timerModel.completedIntervals)/\(timerModel.totalIntervals)")
                        .font(
                            .system(
                                size: sizes.primaryFont,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Intervals completed")
                        .accessibilityValue(
                            "\(timerModel.completedIntervals) of \(timerModel.totalIntervals)"
                        )
                } else {
                    Text(timerModel.intervalTimeRemaining.formatted)
                        .font(
                            .system(
                                size: sizes.primaryFont,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Interval time")
                        .accessibilityValue(
                            timerModel.intervalTimeRemaining.formatted
                        )
                }

                if let visibleHint = context.visibleHint {
                    TimerHintLine(text: visibleHint, context: context, minimumScaleFactor: 0.9)
                } else {
                    RepsPill(text: makeRepsText(accent: accentColor), accentColor: accentColor, fontSize: sizes.pillFont)
                        .accessibilityLabel("Round \(timerModel.currentInterval) of \(timerModel.totalIntervals)")
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("EMOM Timer") {
    NavigationStack {
        EMOMTimerView(
            timerModel: EMOMTimerModel(
                totalReps: 100,
                totalMinutes: 20,
                timerProvider: DisplayLinkTimerProvider(),
                feedbackProvider: DefaultFeedback()
            )
        )
    }
    .previewTimerSession()
}
