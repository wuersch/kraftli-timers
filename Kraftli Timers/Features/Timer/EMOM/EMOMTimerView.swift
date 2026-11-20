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
    private let config: TimerConfig
    private let link: TimerScreenLink

    /// When true, shows reps count prominently in center instead of interval countdown.
    private let showRepsInCenter: Bool

    init(
        timerModel: EMOMTimerModel,
        config: TimerConfig,
        showRepsInCenter: Bool = false,
        link: TimerScreenLink = TimerScreenLink()
    ) {
        self.timerModel = timerModel
        self.config = config
        self.showRepsInCenter = showRepsInCenter
        self.link = link
    }

    // MARK: - Styling
    private var isCompleted: Bool { timerModel.isCompleted }

    private var accentColor: Color {
        if isCompleted { return .green }
        return timerModel.isIntervalWarning ? .orange : TimerKind.emom.color
    }

    /// "3/20": the rep in progress, or the reps done once completed.
    private var repsValue: String {
        let reps = isCompleted ? timerModel.completedIntervals : timerModel.currentInterval
        return "\(reps)/\(timerModel.totalIntervals)"
    }

    var body: some View {
        TimerScreen(
            model: timerModel,
            config: config,
            link: link,
            total: TimerScreenTotal(
                time: timerModel.totalTimeRemaining,
                totalDuration: timerModel.totalDuration
            ),
            accessibilitySummary: "rep \(timerModel.currentInterval) of \(timerModel.totalIntervals)"
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
            rotationDegrees: -89.5
        )

        if let outerRing = context.sizes.secondaryRing, let outerLineWidth = context.sizes.secondaryLineWidth {
            ProgressRing(
                size: outerRing,
                lineWidth: outerLineWidth,
                progress: isFull ? 1.0 : timerModel.overallProgress,
                color: .primary,
                rotationDegrees: -90.5
            )
        }
    }

    // MARK: - Center Content

    @ViewBuilder
    private func centerContent(_ context: TimerScreenContext) -> some View {
        let reps = "\(timerModel.currentInterval) of \(timerModel.totalIntervals)"
        if showRepsInCenter {
            // Reps-focused: the rep count, with the interval time as secondary info.
            TimerCenterStack(
                label: "REPS",
                value: repsValue,
                weight: .semibold,
                accessibilityLabel: "Reps completed",
                accessibilityValue: reps,
                context: context
            ) {
                Text(timerModel.intervalTimeRemaining.formatted)
                    .font(.system(size: context.sizes.labelFont, weight: .medium, design: .rounded))
                    .foregroundStyle(accentColor)
                    .monospacedDigit()
                    .accessibilityLabel("Interval time remaining")
                    .accessibilityValue(timerModel.intervalTimeRemaining.formatted)
            }
        } else if isCompleted {
            // Interval-focused, once done: the intervals completed.
            TimerCenterStack(
                label: "INTERVALS",
                value: repsValue,
                weight: .semibold,
                accessibilityLabel: "Intervals completed",
                accessibilityValue: "\(timerModel.completedIntervals) of \(timerModel.totalIntervals)",
                context: context
            )
        } else {
            // Interval-focused: the interval countdown, with the rep in progress below.
            TimerCenterStack(
                label: "INTERVAL",
                value: timerModel.intervalTimeRemaining.formatted,
                weight: .semibold,
                color: accentColor,
                accessibilityLabel: "Interval time",
                accessibilityValue: timerModel.intervalTimeRemaining.formatted,
                context: context
            ) {
                RepsPill(text: repsPillText, accentColor: accentColor, fontSize: context.sizes.pillFont)
                    .accessibilityLabel("Round \(reps)")
            }
        }
    }

    /// "3/20 REPS", with "REPS" in the accent color.
    private var repsPillText: AttributedString {
        var text = AttributedString("\(repsValue) REPS")
        text.foregroundColor = .primary
        if let range = text.range(of: " REPS") {
            text[range].foregroundColor = accentColor
        }
        return text
    }
}

// MARK: - Preview
#Preview("EMOM Timer") {
    NavigationStack {
        KindTimerView(
            config: TimerConfig(kind: .emom, duration: 20 * 60, targetReps: 100, exerciseName: "Burpees"),
            feedbackProvider: DefaultFeedback(),
            link: TimerScreenLink()
        )
    }
    .environment(AppSettings())
    .previewTimerSession()
}
