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
    private let config: TimerConfig
    private let link: TimerScreenLink

    init(timerModel: AMRAPTimerModel, config: TimerConfig, link: TimerScreenLink = TimerScreenLink()) {
        self.timerModel = timerModel
        self.config = config
        self.link = link
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
            accessibilitySummary: "\(timerModel.roundsCompleted) rounds completed"
        ) { context in
            ProgressRing(
                size: context.sizes.primaryRing,
                lineWidth: context.sizes.primaryLineWidth,
                progress: context.isCompleted || context.isWaitingToStart ? 1.0 : timerModel.progress,
                color: TimerKind.amrap.color
            )
        } center: { context in
            TimerCenterStack(
                label: "ROUNDS",
                value: "\(timerModel.roundsCompleted)",
                color: TimerKind.amrap.color,
                accessibilityLabel: "\(timerModel.roundsCompleted) rounds completed",
                context: context
            )
        }
    }
}

// MARK: - Preview
#Preview("AMRAP Timer") {
    NavigationStack {
        KindTimerView(
            config: TimerConfig(kind: .amrap, duration: 5 * 60, targetReps: nil, exerciseName: "Pull-ups"),
            feedbackProvider: DefaultFeedback(),
            link: TimerScreenLink()
        )
    }
    .environment(AppSettings())
    .previewTimerSession()
}
