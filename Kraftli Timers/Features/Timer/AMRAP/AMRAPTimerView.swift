//
//  AMRAPTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit
import Combine

// MARK: - AMRAPTimerView
struct AMRAPTimerView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss

    @State private var timerModel: AMRAPTimerModel
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

    /// Service for syncing timer controls with Apple Watch (nil for standalone timers).
    private let syncService: TimerSyncService?

    /// Exercise name for Watch sync message.
    private let exerciseName: String

    // MARK: - Haptics
    private static let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Computed Properties
    private var isCompleted: Bool { timerModel.isCompleted }

    // MARK: - Initialization
    init(
        timerModel: AMRAPTimerModel = AMRAPTimerModel(
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: SystemSoundFeedback()
        ),
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
        confettiEnabled: Bool = true,
        syncService: TimerSyncService? = nil,
        exerciseName: String = "Workout"
    ) {
        self.timerModel = timerModel
        self.onWorkoutCompleted = onWorkoutCompleted
        self.confettiEnabled = confettiEnabled
        self.syncService = syncService
        self.exerciseName = exerciseName
    }

    // MARK: - Styling
    private let accentColor: Color = .indigo


    // MARK: - Actions
    private func handleTap() {
        guard !isCompleted else { return }

        // Ignore taps during countdown
        guard !countdown.isCountingDown else { return }

        guard timerModel.isRunning else {
            startCountdown()
            Self.lightHaptic.impactOccurred()
            return
        }

        timerModel.incrementRoundsCompleted()
        syncService?.sendTimerControl(.incrementRound, completion: nil)
        Self.lightHaptic.impactOccurred()
    }

    private func handleLongPress() {
        guard !isCompleted else { return }

        // Ignore long press during countdown
        guard !countdown.isCountingDown else { return }

        if timerModel.isRunning {
            timerModel.pause()
            session.onTimerPaused()
            syncService?.sendTimerControl(.pause, completion: nil)
            Self.mediumHaptic.impactOccurred()
        } else {
            startCountdown()
            Self.lightHaptic.impactOccurred()
        }
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
            kind: .amrap,
            totalDuration: timerModel.totalDuration,
            intervalDuration: nil,
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
                },
                onIncrementRound: { [self] in
                    if timerModel.isRunning && !isCompleted {
                        timerModel.incrementRoundsCompleted()
                    }
                }
            ),
            cancellables: &cancellables
        )
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = TimerSizes.amrap(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    // Ring and center content
                    ZStack {
                        ProgressRing(
                            size: sizes.primaryRing,
                            lineWidth: sizes.primaryLineWidth,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.progress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90
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
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint(accessibilityHint)
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
                .onLongPressGesture(minimumDuration: 0.8) {
                    handleLongPress()
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
            Self.mediumHaptic.prepare()
            setupControlSubscription()
        }
    }

    // MARK: - Countdown Center Content
    @ViewBuilder
    private func countdownCenterContent(sizes: TimerSizes) -> some View {
        CountdownText(
            countdownValue: countdown.countdownValue,
            fontSize: sizes.primaryFont * 1.2
        )
    }

    // MARK: - Normal Center Content
    @ViewBuilder
    private func normalCenterContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 8) {
            Text("ROUNDS")
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)

            Text("\(timerModel.roundsCompleted)")
                .font(
                    .system(
                        size: sizes.primaryFont,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(timerModel.roundsCompleted) rounds completed")

            if isCompleted {
                RepsPill(text: makeCompletionText(), accentColor: .green, fontSize: sizes.pillFont)
                    .accessibilityLabel("Timer completed")
                    .accessibilityHint("Swipe down to close")
            } else if session.showHint {
                Text(hintText)
                    .font(.system(size: sizes.labelFont))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.98))
                    )
                    .accessibilityHidden(true)
            } else {
                // Invisible spacer to prevent layout shift
                Text(hintText)
                    .font(.system(size: sizes.labelFont))
                    .lineLimit(1)
                    .hidden()
            }
        }
    }

    // MARK: - Helpers
    private func makeCompletionText() -> AttributedString {
        var attr = AttributedString("DONE")
        attr.foregroundColor = .green
        return attr
    }

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
        if isCompleted {
            return "Timer completed, \(timerModel.roundsCompleted) rounds"
        } else if timerModel.isRunning {
            return "AMRAP Timer running, \(timerModel.roundsCompleted) rounds completed"
        } else {
            return "AMRAP Timer paused, \(timerModel.roundsCompleted) rounds completed"
        }
    }

    private var accessibilityHint: String {
        if isCompleted {
            return "Swipe down to close"
        } else if timerModel.isRunning {
            return "Tap to add round, hold to pause, swipe down to close"
        } else {
            return "Tap to start, hold to pause, swipe down to close"
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
                feedbackProvider: SystemSoundFeedback()
            )
        )
    }
}
