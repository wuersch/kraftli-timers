//
//  AMRAPTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit
import Combine

// MARK: - TimerSizes
/// Holds all calculated sizes for responsive layout
private struct TimerSizes {
    let ring: CGFloat
    let ringLineWidth: CGFloat
    let countFont: CGFloat
    let totalFont: CGFloat
    let labelFont: CGFloat
    let pillFont: CGFloat
    let spacing: CGFloat
}

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
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

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

    // MARK: - Responsive Sizing
    /// Calculates proportional sizes based on available space.
    /// Uses the smaller of width or height*0.55 to ensure content fits.
    private func sizes(for size: CGSize) -> TimerSizes {
        let heightConstrained = size.height * 0.55
        let effectiveWidth = min(size.width, heightConstrained, 600)
        return TimerSizes(
            ring: effectiveWidth * 0.75,
            ringLineWidth: effectiveWidth * 0.05,
            countFont: effectiveWidth * 0.20,
            totalFont: effectiveWidth * 0.15,
            labelFont: effectiveWidth * 0.038,
            pillFont: effectiveWidth * 0.038,
            spacing: effectiveWidth * 0.10
        )
    }

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

    /// Sets up subscription to receive control messages from Apple Watch.
    private func setupControlSubscription() {
        syncService?.timerControlReceived
            .receive(on: DispatchQueue.main)
            .sink { [self] action in
                handleRemoteControl(action)
            }
            .store(in: &cancellables)
    }

    /// Handles control messages received from Apple Watch.
    private func handleRemoteControl(_ action: TimerControlAction) {
        switch action {
        case .play:
            if !timerModel.isRunning && !isCompleted && !countdown.isCountingDown {
                startCountdown()
            }
        case .pause:
            if timerModel.isRunning {
                timerModel.pause()
                session.onTimerPaused()
            }
        case .stop:
            countdown.cancelCountdown()
            timerModel.reset()
            dismiss()
        case .incrementRound:
            if timerModel.isRunning && !isCompleted {
                timerModel.incrementRoundsCompleted()
            }
        }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = sizes(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    // Ring and center content
                    ZStack {
                        ProgressRing(
                            size: sizes.ring,
                            lineWidth: sizes.ringLineWidth,
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

                    // Bottom section - ZStack maintains consistent height
                    ZStack {
                        // Normal TOTAL section (always present for layout)
                        VStack(spacing: 8) {
                            Text("TOTAL")
                                .font(.system(size: sizes.labelFont))
                                .foregroundStyle(.gray)

                            Text(timerModel.totalTimeRemaining.formatted)
                                .font(
                                    .system(size: sizes.totalFont, weight: .bold, design: .rounded)
                                )
                                .monospacedDigit()
                                .accessibilityLabel("Total time")
                                .accessibilityValue(timerModel.totalTimeRemaining.formatted)
                        }
                        .opacity(countdown.isCountingDown ? 0 : 1)

                        // "Get ready" text (shown during countdown)
                        Text("Get ready")
                            .font(.system(size: sizes.totalFont * 0.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, sizes.spacing * 0.4)
                            .opacity(countdown.isCountingDown ? 1 : 0)
                    }
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

                // Hide handle during countdown
                if !countdown.isCountingDown {
                    DragHandleView(isActive: isHandleActive, dragOffset: dragOffset)
                }

                // Hide swipe hint during countdown
                if !countdown.isCountingDown {
                    SwipeHintOverlay(isVisible: session.showHint, fontSize: sizes.labelFont)
                }

                if confettiEnabled && session.showConfetti {
                    ConfettiView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                }
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
        let displayText = countdown.countdownValue.map { $0 > 0 ? "\($0)" : "GO" } ?? ""
        let textColor: Color = .primary

        Text(displayText)
            .font(.system(size: sizes.countFont * 1.2, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .contentTransition(.numericText())
            .id(countdown.countdownValue)
            .accessibilityLabel(displayText)
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
                        size: sizes.countFont,
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
