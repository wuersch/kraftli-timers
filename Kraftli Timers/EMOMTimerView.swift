//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit

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
    @State private var dragOffset: CGFloat = 0
    @State private var isHandleActive = false

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
            totalMinutes: 1
        )
    ) {
        self.timerModel = timerModel
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
        attr.foregroundColor = accent
        if let repsRange = attr.range(of: " REPS") {
            attr[repsRange].foregroundColor = .primary
        }
        return attr
    }

    private func makeCompletionText() -> AttributedString {
        var attr = AttributedString("DONE")
        attr.foregroundColor = .green
        return attr
    }
    
    // MARK: - Actions
    private func handleTap() {
        guard !isCompleted else { return }

        if timerModel.isRunning {
            timerModel.pause()
            session.onTimerPaused()
        } else {
            startAndScheduleHintHide()
        }
        Self.lightHaptic.impactOccurred()
    }

    private func handleSwipeDismiss() {
        timerModel.reset()
        dismiss()
    }

    private func startAndScheduleHintHide() {
        guard !timerModel.isRunning else { return }
        timerModel.start()
        session.onTimerStarted { [timerModel] in timerModel.isRunning }
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = sizes(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    ZStack {
                        ProgressRing(
                            size: sizes.innerRing,
                            lineWidth: sizes.innerLineWidth,
                            progress: timerModel.intervalProgress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -89.5
                        )
                        .accessibilityHidden(true)

                        ProgressRing(
                            size: sizes.outerRing,
                            lineWidth: sizes.outerLineWidth,
                            progress: timerModel.overallProgress,
                            color: .primary,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90.5
                        )
                        .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text("INTERVAL")
                                .font(.system(size: sizes.labelFont))
                                .foregroundStyle(.gray)

                            Text(timerModel.intervalTimeRemaining.formatted)
                                .font(
                                    .system(
                                        size: sizes.intervalFont,
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

                            if isCompleted {
                                RepsPill(text: makeCompletionText(), accentColor: .green, fontSize: sizes.pillFont)
                                    .accessibilityLabel("Timer completed")
                                    .accessibilityHint("Swipe down to close")
                            } else if session.showHint {
                                Text(
                                    timerModel.isRunning
                                        ? "Tap to pause"
                                        : "Tap to start"
                                )
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
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(isCompleted ? "Timer completed" : (timerModel.isRunning ? "Timer running" : "Timer paused"))
                    .accessibilityHint(isCompleted ? "Swipe down to close" : (timerModel.isRunning ? "Tap to pause, swipe down to close" : "Tap to start, swipe down to close"))
                    .accessibilityAddTraits(isCompleted ? [] : .isButton)

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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
                .swipeToDismiss(
                    dragOffset: $dragOffset,
                    isHandleActive: $isHandleActive,
                    onDismiss: handleSwipeDismiss
                )

                DragHandleView(isActive: isHandleActive, dragOffset: dragOffset)

                SwipeHintOverlay(isVisible: session.showHint, fontSize: sizes.labelFont)

                if session.showConfetti {
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
            onDisappear: { timerModel.pause() }
        )
        .onAppear {
            Self.lightHaptic.prepare()
        }
    }
}

// MARK: - Preview
#Preview("EMOM Timer") {
    NavigationStack {
        EMOMTimerView(
            timerModel: EMOMTimerModel(totalReps: 100, totalMinutes: 20)
        )
    }
}

