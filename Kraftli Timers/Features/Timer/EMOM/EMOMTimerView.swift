//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit
import Combine

// MARK: - EMOMTimerView
struct EMOMTimerView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss

    @State private var timerModel: EMOMTimerModel
    @State private var session = TimerSessionState()
    @State private var countdown = CountdownCoordinator()
    @State private var dragOffset: CGFloat = 0
    @State private var isHandleActive = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isPulsing = false

    /// Called when the workout completes (timer reaches zero). Used for logging.
    private let onWorkoutCompleted: ((WorkoutCompletionData) -> Void)?

    /// Whether to show confetti on workout completion.
    private let confettiEnabled: Bool

    /// Whether to show reps count in center instead of interval countdown.
    private let showRepsInCenter: Bool

    /// Service for syncing timer controls with Apple Watch (nil for standalone timers).
    private let syncService: TimerSyncService?

    /// Exercise name for Watch sync message.
    private let exerciseName: String

    /// Interval duration for Watch sync message (EMOM-specific).
    private let syncIntervalDuration: TimeInterval?

    // MARK: - Haptics
    private static let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Computed Properties
    private var isCompleted: Bool { timerModel.isCompleted }

    // MARK: - Initialization
    init(
        timerModel: EMOMTimerModel = EMOMTimerModel(
            totalReps: 5,
            totalMinutes: 1,
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: SystemSoundFeedback()
        ),
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
        confettiEnabled: Bool = true,
        showRepsInCenter: Bool = false,
        syncService: TimerSyncService? = nil,
        exerciseName: String = "Workout",
        syncIntervalDuration: TimeInterval? = nil
    ) {
        self.timerModel = timerModel
        self.onWorkoutCompleted = onWorkoutCompleted
        self.confettiEnabled = confettiEnabled
        self.showRepsInCenter = showRepsInCenter
        self.syncService = syncService
        self.exerciseName = exerciseName
        self.syncIntervalDuration = syncIntervalDuration
    }

    // MARK: - Styling
    private var accentColor: Color {
        timerModel.isIntervalWarning ? .orange : .blue
    }


    // MARK: - Helpers
    private func makeRepsText(accent: Color) -> AttributedString {
        var attr = AttributedString("\(timerModel.completedIntervals)/\(timerModel.totalIntervals) REPS")
        attr.foregroundColor = .primary
        if let repsRange = attr.range(of: " REPS") {
            attr[repsRange].foregroundColor = accent
        }
        return attr
    }

    private func makeCompletionText() -> AttributedString {
        var attr = AttributedString("DONE")
        attr.foregroundColor = .green
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

    // MARK: - Actions
    private func handleTap() {
        guard !isCompleted else { return }

        // Ignore taps during countdown
        guard !countdown.isCountingDown else { return }

        if timerModel.isRunning {
            timerModel.pause()
            session.onTimerPaused()
            syncService?.sendTimerControl(.pause, completion: nil)
        } else {
            startCountdown()
        }
        Self.lightHaptic.impactOccurred()
    }

    private func handleSwipeDismiss() {
        countdown.cancelCountdown()
        timerModel.reset()
        syncService?.sendTimerControl(.stop, completion: nil)
        dismiss()
    }

    private func startCountdown() {
        // Skip countdown on resume - timer starts immediately
        if session.hasEverStarted {
            startAndScheduleHintHide()
            syncService?.sendTimerControl(.play, completion: nil)
            return
        }

        // Calculate absolute start time (3 seconds from now)
        let scheduledStartTime = Date().addingTimeInterval(3.0)

        // Send timer config to Watch with scheduled start time
        syncService?.startTimerOnWatch(
            kind: .emom,
            totalDuration: timerModel.totalDuration,
            intervalDuration: syncIntervalDuration,
            exerciseName: exerciseName,
            scheduledStartTime: scheduledStartTime,
            completion: nil
        )

        // Start local countdown
        countdown.startCountdown(scheduledStartTime: scheduledStartTime) { [self] in
            startAndScheduleHintHide()
        }
    }

    private func startAndScheduleHintHide() {
        guard !timerModel.isRunning else { return }
        timerModel.start()
        session.onTimerStarted { [timerModel] in timerModel.isRunning }
    }

    // MARK: - Watch Sync

    private func setupControlSubscription() {
        WatchSyncHandler.setupSubscription(
            syncService: syncService,
            callbacks: WatchSyncCallbacks(
                onPlay: { [self] in
                    if !timerModel.isRunning && !isCompleted && !countdown.isCountingDown {
                        startCountdown()
                    }
                },
                onPause: { [self] in
                    if timerModel.isRunning {
                        timerModel.pause()
                        session.onTimerPaused()
                    }
                },
                onStop: { [self] in
                    countdown.cancelCountdown()
                    timerModel.reset()
                    dismiss()
                }
            ),
            cancellables: &cancellables
        )
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = TimerSizes.emom(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    ZStack {
                        // Rings - stay full during countdown
                        ProgressRing(
                            size: sizes.primaryRing,
                            lineWidth: sizes.primaryLineWidth,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.intervalProgress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -89.5
                        )
                        .accessibilityHidden(true)

                        ProgressRing(
                            size: sizes.secondaryRing!,
                            lineWidth: sizes.secondaryLineWidth!,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.overallProgress,
                            color: .primary,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90.5
                        )
                        .accessibilityHidden(true)

                        // Center content - switches between countdown and normal display
                        if countdown.isCountingDown {
                            countdownCenterContent(sizes: sizes)
                        } else {
                            normalCenterContent(sizes: sizes)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(isCompleted ? "Timer completed" : (timerModel.isRunning ? "Timer running" : "Timer paused"))
                    .accessibilityHint(isCompleted ? "Swipe down to close" : "\(hintText), swipe down to close")
                    .accessibilityAddTraits(isCompleted ? [] : .isButton)

                    TimerBottomSection(
                        totalTimeRemaining: timerModel.totalTimeRemaining,
                        isCountingDown: countdown.isCountingDown,
                        isPulsing: $isPulsing,
                        sizes: sizes
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
                .swipeToDismiss(
                    dragOffset: $dragOffset,
                    isHandleActive: $isHandleActive,
                    onDismiss: handleSwipeDismiss,
                    isDisabled: countdown.isCountingDown
                )

                TimerOverlays(
                    isCountingDown: countdown.isCountingDown,
                    isHandleActive: isHandleActive,
                    dragOffset: dragOffset,
                    showHint: session.showHint,
                    showConfetti: session.showConfetti,
                    confettiEnabled: confettiEnabled,
                    labelFont: sizes.labelFont
                )
            }
        }
        .timerLifecycle(
            timer: timerModel,
            session: session,
            onPause: { timerModel.pause() },
            onDisappear: { timerModel.pause() },
            onWorkoutCompleted: onWorkoutCompleted
        )
        .onAppear {
            Self.lightHaptic.prepare()
            setupControlSubscription()
        }
    }

    // MARK: - Countdown Center Content
    @ViewBuilder
    private func countdownCenterContent(sizes: TimerSizes) -> some View {
        CountdownText(
            countdownValue: countdown.countdownValue,
            fontSize: sizes.primaryFont * 1.5
        )
    }

    // MARK: - Normal Center Content
    @ViewBuilder
    private func normalCenterContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 8) {
            Text(showRepsInCenter ? "REPS" : "INTERVAL")
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)

            if showRepsInCenter {
                // Reps-focused mode: show reps count prominently
                Text("\(timerModel.completedIntervals)/\(timerModel.totalIntervals)")
                    .font(
                        .system(
                            size: sizes.primaryFont,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(isCompleted ? .green : .primary)
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Reps completed")
                    .accessibilityValue(
                        "\(timerModel.completedIntervals) of \(timerModel.totalIntervals)"
                    )

                // Third element for vertical balance
                if isCompleted {
                    Text("DONE")
                        .font(.system(size: sizes.pillFont, weight: .semibold))
                        .foregroundStyle(.green)
                        .accessibilityLabel("Timer completed")
                } else if session.showHint {
                    Text(hintText)
                        .font(.system(size: sizes.labelFont))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.98))
                        )
                        .accessibilityHidden(true)
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
                // Interval-focused mode: show countdown
                Text(timerModel.intervalTimeRemaining.formatted)
                    .font(
                        .system(
                            size: sizes.primaryFont,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(isCompleted ? Color.gray.opacity(0.2) : accentColor)
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Interval time")
                    .accessibilityValue(
                        timerModel.intervalTimeRemaining.formatted
                    )

                if isCompleted {
                    RepsPill(text: makeCompletionText(), accentColor: .green, fontSize: sizes.pillFont)
                        .accessibilityLabel("Timer completed")
                        .accessibilityHint("Swipe down to close")
                } else if session.showHint {
                    Text(hintText)
                        .font(.system(size: sizes.labelFont))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.98))
                        )
                        .accessibilityHidden(true)
                } else {
                    RepsPill(text: makeRepsText(accent: accentColor), accentColor: accentColor, fontSize: sizes.pillFont)
                        .accessibilityLabel("\(timerModel.completedIntervals) of \(timerModel.totalIntervals) repetitions completed")
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
                feedbackProvider: SystemSoundFeedback()
            )
        )
    }
}

