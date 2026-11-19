//
//  AMRAPTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI

// MARK: - AMRAPTimerView

/// The AMRAP face of `TimerScreen`: one ring draining with the time, and the round
/// count in the center. Rounds are part of the timer state (`roundCount`), so taps on
/// either device add up.
struct AMRAPTimerView: View {
    @State private var timerModel: AMRAPTimerModel
    private let link: TimerScreenLink

    private let accentColor = TimerKind.amrap.color

    init(
        timerModel: AMRAPTimerModel = AMRAPTimerModel(
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: DefaultFeedback()
        ),
        link: TimerScreenLink = TimerScreenLink()
    ) {
        self.timerModel = timerModel
        self.link = link
    }

    var body: some View {
        TimerScreen(
            model: timerModel,
            config: TimerConfig(
                kind: .amrap,
                totalDuration: timerModel.totalDuration,
                intervalCount: nil,
                exerciseName: link.exerciseName
            ),
            link: link,
            style: TimerScreenStyle(
                sizes: { TimerSizes.amrap(for: $0) },
                color: accentColor,
                startingIconScale: 0.5,
                countdownScale: 1.2
            ),
            runningTap: .countRound,
            holdTogglesPause: true,
            hintText: hintText,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            total: TimerScreenTotal(
                time: timerModel.totalTimeRemaining,
                totalDuration: timerModel.totalDuration
            )
        ) { context in
            ProgressRing(
                size: context.sizes.primaryRing,
                lineWidth: context.sizes.primaryLineWidth,
                progress: context.isCompleted || context.isWaitingToStart ? 1.0 : timerModel.progress,
                color: accentColor,
                backgroundColor: Color.gray.opacity(0.2),
                rotationDegrees: -90
            )
        } center: { context in
            centerContent(context)
        }
    }

    // MARK: - Center Content
    private func centerContent(_ context: TimerScreenContext) -> some View {
        VStack(spacing: 8) {
            Text("ROUNDS")
                .font(.system(size: context.sizes.labelFont))
                .foregroundStyle(.gray)

            Text("\(timerModel.roundsCompleted)")
                .font(
                    .system(
                        size: context.sizes.primaryFont,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(timerModel.roundsCompleted) rounds completed")

            if let visibleHint = context.visibleHint {
                TimerHintLine(text: visibleHint, context: context, minimumScaleFactor: 0.8)
            } else {
                // Invisible spacer to prevent layout shift
                Text(hintText)
                    .font(.system(size: context.sizes.labelFont))
                    .lineLimit(1)
                    .hidden()
            }
        }
    }

    // MARK: - Strings

    private var hintText: String {
        if !timerModel.isRunning && timerModel.elapsedTime <= 0 {
            return "Tap to start"
        } else if timerModel.isRunning {
            return "Tap to count · Hold to pause"
        } else {
            return "Tap to resume"
        }
    }

    private var accessibilityLabel: String {
        if timerModel.isCompleted {
            return "Timer completed, \(timerModel.roundsCompleted) rounds"
        } else if timerModel.isRunning {
            return "AMRAP Timer running, \(timerModel.roundsCompleted) rounds completed"
        } else {
            return "AMRAP Timer paused, \(timerModel.roundsCompleted) rounds completed"
        }
    }

    private var accessibilityHint: String {
        if timerModel.isCompleted {
            return "Swipe down to close"
        } else if timerModel.isRunning {
            return "Tap to add round, hold to pause, swipe down to close"
        } else {
            return "Tap or hold to resume, swipe down to close"
        }
    }
}

// MARK: - Preview
#Preview("AMRAP Timer") {
    NavigationStack {
        AMRAPTimerView(
            timerModel: AMRAPTimerModel(
                totalDuration: 5 * 60,
                timerProvider: DisplayLinkTimerProvider(),
                feedbackProvider: DefaultFeedback()
            )
        )
    }
    .previewTimerSession()
}
