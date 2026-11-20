//
//  ForTimeTimerView.swift
//  Kraftli Timers
//
//  Runs a For Time workout: a stopwatch the athlete stops by declaring done.
//

import SwiftUI

// MARK: - ForTimeTimerView

/// The For Time face of `TimerScreen` (ADR-0010): a comet circling the ring like a
/// stopwatch hand, and the target reps in the center. A tap declares the workout done;
/// the owner turns that into a completion.
struct ForTimeTimerView: View {
    @State private var timerModel: ForTimeTimerModel
    private let config: TimerConfig
    private let link: TimerScreenLink

    private let accentColor = TimerKind.forTime.color

    init(timerModel: ForTimeTimerModel, config: TimerConfig, link: TimerScreenLink = TimerScreenLink()) {
        self.timerModel = timerModel
        self.config = config
        self.link = link
    }

    var body: some View {
        TimerScreen(
            model: timerModel,
            config: config,
            link: link,
            total: TimerScreenTotal(time: timerModel.elapsedTime, countsUp: true),
            accessibilitySummary: accessibilitySummary
        ) { context in
            circlingArc(context)
        } center: { context in
            TimerCenterStack(
                label: "REPS",
                value: "\(timerModel.targetReps)",
                color: accentColor,
                accessibilityLabel: "\(timerModel.targetReps) reps",
                context: context
            )
        }
    }

    // MARK: - Circling Arc

    /// A comet that circles the ring once per lap (10 s), like a stopwatch hand. It rests at the
    /// top before the start, freezes while paused, and closes into a full ring when done.
    @ViewBuilder
    private func circlingArc(_ context: TimerScreenContext) -> some View {
        if context.isCompleted {
            ProgressRing(
                size: context.sizes.primaryRing,
                lineWidth: context.sizes.primaryLineWidth,
                progress: 1.0,
                color: accentColor
            )
        } else {
            let lapProgress = context.isWaitingToStart ? 0 : timerModel.lapProgress
            CometRing(
                size: context.sizes.primaryRing,
                lineWidth: context.sizes.primaryLineWidth,
                // The head points to 12 o'clock at the start of each lap.
                headAngle: .degrees(lapProgress * 360),
                color: accentColor
            )
        }
    }

    private var accessibilitySummary: String {
        let elapsed = timerModel.elapsedTime.formatted
        let time = timerModel.isCompleted ? "finish time \(elapsed)" : "\(elapsed) elapsed"
        return "\(time), \(timerModel.targetReps) reps"
    }
}

// MARK: - Preview
#Preview("For Time Timer") {
    NavigationStack {
        KindTimerView(
            config: TimerConfig(kind: .forTime, duration: 0, targetReps: 50, exerciseName: "Burpees"),
            feedbackProvider: DefaultFeedback(),
            link: TimerScreenLink()
        )
    }
    .environment(AppSettings())
    .previewTimerSession()
}
