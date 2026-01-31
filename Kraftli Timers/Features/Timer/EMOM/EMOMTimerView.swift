//
//  EMOMTimerView.swift
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
    let outerRing: CGFloat
    let innerRing: CGFloat
    let outerLineWidth: CGFloat
    let innerLineWidth: CGFloat
    let intervalFont: CGFloat
    let totalFont: CGFloat
    let labelFont: CGFloat
    let pillFont: CGFloat
    let spacing: CGFloat
}

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
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

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

    // MARK: - Responsive Sizing
    /// Calculates proportional sizes based on available space.
    /// Uses the smaller of width or height*0.55 to ensure content fits in landscape.
    /// Reference: iPhone 14 Pro width ≈ 393pt with outer ring 320pt, inner ring 280pt.
    private func sizes(for size: CGSize) -> TimerSizes {
        // Use height * 0.55 as the vertical constraint (rings + total section need ~55% of height)
        let heightConstrained = size.height * 0.55
        let effectiveWidth = min(size.width, heightConstrained, 600)
        return TimerSizes(
            outerRing: effectiveWidth * 0.81,      // 320/393
            innerRing: effectiveWidth * 0.71,      // 280/393
            outerLineWidth: effectiveWidth * 0.025, // 10/393
            innerLineWidth: effectiveWidth * 0.05,  // 20/393
            intervalFont: effectiveWidth * 0.14,    // 56/393
            totalFont: effectiveWidth * 0.15,       // 60/393
            labelFont: effectiveWidth * 0.038,      // ~15/393 (subheadline equivalent)
            pillFont: effectiveWidth * 0.038,       // ~15/393 (subheadline equivalent)
            spacing: effectiveWidth * 0.10          // 40/393
        )
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
            break  // Not applicable to EMOM timers
        }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = sizes(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    ZStack {
                        // Rings - stay full during countdown
                        ProgressRing(
                            size: sizes.innerRing,
                            lineWidth: sizes.innerLineWidth,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.intervalProgress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -89.5
                        )
                        .accessibilityHidden(true)

                        ProgressRing(
                            size: sizes.outerRing,
                            lineWidth: sizes.outerLineWidth,
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
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Total time")
                                .accessibilityValue(
                                    timerModel.totalTimeRemaining.formatted
                                )
                        }
                        .opacity(countdown.isCountingDown ? 0 : 1)

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
                            .opacity(countdown.isCountingDown ? 1 : 0)
                            .onChange(of: countdown.isCountingDown) { _, isCountingDown in
                                isPulsing = isCountingDown
                            }
                    }
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
            setupControlSubscription()
        }
    }

    // MARK: - Countdown Center Content
    @ViewBuilder
    private func countdownCenterContent(sizes: TimerSizes) -> some View {
        let displayText = countdown.countdownValue.map { $0 > 0 ? "\($0)" : "GO" } ?? ""
        let textColor: Color = .primary

        Text(displayText)
            .font(.system(size: sizes.intervalFont * 1.5, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .contentTransition(.numericText())
            .id(countdown.countdownValue)
            .accessibilityLabel(displayText)
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
                            size: sizes.intervalFont,
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
                            size: sizes.intervalFont,
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

