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
    private let link: TimerScreenLink

    private let accentColor = TimerKind.forTime.color

    init(
        timerModel: ForTimeTimerModel = ForTimeTimerModel(
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
                kind: .forTime,
                totalDuration: nil,
                intervalCount: nil,
                exerciseName: link.exerciseName,
                targetReps: timerModel.targetReps
            ),
            link: link,
            style: TimerScreenStyle(
                sizes: { TimerSizes.amrap(for: $0) },
                color: accentColor,
                startingIconScale: 0.5,
                countdownScale: 1.2
            ),
            runningTap: .declareDone,
            holdTogglesPause: true,
            hintText: hintText,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            total: TimerScreenTotal(time: timerModel.elapsedTime, countsUp: true)
        ) { context in
            circlingArc(context)
        } center: { context in
            centerContent(context)
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
                color: accentColor,
                backgroundColor: Color.gray.opacity(0.2),
                rotationDegrees: -90
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

    // MARK: - Center Content
    private func centerContent(_ context: TimerScreenContext) -> some View {
        VStack(spacing: 8) {
            Text("REPS")
                .font(.system(size: context.sizes.labelFont))
                .foregroundStyle(.gray)

            Text("\(timerModel.targetReps)")
                .font(
                    .system(
                        size: context.sizes.primaryFont,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .accessibilityLabel("\(timerModel.targetReps) reps")

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
            return "Tap when done · Hold to pause"
        } else {
            return "Tap to resume"
        }
    }

    private var accessibilityLabel: String {
        let elapsed = timerModel.elapsedTime.formatted
        if timerModel.isCompleted {
            return "Done, finish time \(elapsed), \(timerModel.targetReps) reps"
        } else if timerModel.isRunning {
            return "For Time running, \(elapsed) elapsed, \(timerModel.targetReps) reps"
        } else {
            return "For Time paused, \(elapsed) elapsed, \(timerModel.targetReps) reps"
        }
    }

    private var accessibilityHint: String {
        if timerModel.isCompleted {
            return "Swipe down to close"
        } else if timerModel.isRunning {
            return "Tap when done, hold to pause, swipe down to end early"
        } else {
            return "Tap to resume, swipe down to end early"
        }
    }
}

// MARK: - Preview
#Preview("For Time Timer") {
    NavigationStack {
        ForTimeTimerView(
            timerModel: ForTimeTimerModel(
                targetReps: 50,
                timerProvider: DisplayLinkTimerProvider(),
                feedbackProvider: DefaultFeedback()
            )
        )
    }
    .previewTimerSession()
}
