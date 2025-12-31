//
//  AMRAPTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit

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
    @Environment(\.scenePhase) var scenePhase

    @State
    private var timerModel: AMRAPTimerModel
    @State
    private var showConfetti = false
    @State
    private var showHint = true
    @State
    private var dragOffset: CGFloat = 0
    @State
    private var isHandleActive = false
    @State
    private var hintHideTask: Task<Void, Never>?
    @State
    private var confettiHideTask: Task<Void, Never>?

    // MARK: - Haptics
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Computed Properties
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

    // MARK: - Initialization
    init(timerModel: AMRAPTimerModel = AMRAPTimerModel()) {
        self.timerModel = timerModel
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
        guard timerModel.isRunning else {
            startIfNeededAndScheduleHintHide()
            lightHaptic.impactOccurred()
            return
        }

        timerModel.incrementRoundsCompleted()
        lightHaptic.impactOccurred()
    }

    private func handleLongPress() {
        guard !isCompleted else { return }

        if timerModel.isRunning {
            timerModel.pause()
            withAnimation(.easeIn(duration: 0.3)) {
                showHint = true
            }
            mediumHaptic.impactOccurred()
        } else {
            startIfNeededAndScheduleHintHide()
            lightHaptic.impactOccurred()
        }
    }

    private func handleSwipeDismiss() {
        timerModel.reset()
        mediumHaptic.impactOccurred()
        dismiss()
    }

    private func startIfNeededAndScheduleHintHide() {
        guard !timerModel.isRunning else { return }

        timerModel.start()

        if showHint {
            hintHideTask?.cancel()
            hintHideTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, timerModel.isRunning, showHint else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    showHint = false
                }
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
                            progress: timerModel.progress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90
                        )
                        .accessibilityHidden(true)

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
                            } else if showHint {
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
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint(accessibilityHint)
                    .accessibilityAddTraits(isCompleted ? [] : .isButton)

                    // Total time section
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
                .onLongPressGesture(minimumDuration: 0.8) {
                    handleLongPress()
                }
                .offset(y: dragOffset * 0.5)
                .opacity(1.0 - (dragOffset / 700.0))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                                if !isHandleActive {
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        isHandleActive = true
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            let shouldDismiss = value.predictedEndTranslation.height > 200
                                || value.velocity.height > 500

                            if shouldDismiss {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    dragOffset = 800
                                }
                                handleSwipeDismiss()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                    isHandleActive = false
                                }
                            }
                        }
                )

                // Top handle bar
                VStack {
                    Capsule()
                        .fill(isHandleActive ? Color.primary : Color.gray.opacity(0.25))
                        .frame(width: 32, height: 4)
                        .padding(.top, 12)
                    Spacer()
                }
                .offset(y: dragOffset * 0.5)
                .opacity(1.0 - (dragOffset / 700.0))
                .allowsHitTesting(false)

                // Bottom hint overlay
                if showHint {
                    VStack {
                        Spacer()
                        Text("Swipe down to close")
                            .font(.system(size: sizes.labelFont))
                            .foregroundStyle(.gray.opacity(0.6))
                            .padding(.bottom, 20)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                // Confetti Overlay
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                }
            }
        }
        .onDisappear {
            hintHideTask?.cancel()
            confettiHideTask?.cancel()
            timerModel.pause()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: timerModel.isRunning) { oldValue, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background && timerModel.isRunning {
                timerModel.pause()
            }
        }
        .onChange(of: timerModel.totalTimeRemaining) { oldValue, newValue in
            if oldValue > 0 && newValue == 0 {
                showConfetti = true
                showHint = true
                confettiHideTask?.cancel()
                confettiHideTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    showConfetti = false
                }
            }
        }
        .onAppear {
            lightHaptic.prepare()
            mediumHaptic.prepare()
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
            timerModel: AMRAPTimerModel(totalDuration: 5 * 60)
        )
    }
}
