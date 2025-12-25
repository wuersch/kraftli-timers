//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit

// MARK: - EMOMTimerView
struct EMOMTimerView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss

    @State
    private var timerModel: EMOMTimerModel
    @State
    private var showConfetti = false
    @State
    private var showHint = true

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
        var attr = AttributedString("DONE ⸱ Hold to close")
        if let doneRange = attr.range(of: "DONE") {
            attr[doneRange].foregroundColor = .green
        }
        return attr
    }
    
    // MARK: - Haptics
    private func haptic(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: type)
        generator.impactOccurred()
    }

    // MARK: - Actions
    private func handleTap() {
        guard !isCompleted else { return }

        if timerModel.isRunning {
            timerModel.pause()
        } else {
            startIfNeededAndScheduleHintHide()
        }

        haptic(.light)
    }

    private func handleLongPress() {
        timerModel.reset()
        dismiss()
        haptic(.heavy)
    }

    private func startIfNeededAndScheduleHintHide() {
        guard !timerModel.isRunning else { return }
        
        timerModel.start()
        
        if showHint {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showHint = false
                }
            }
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                ZStack {
                    ProgressRing(
                        size: 280,
                        lineWidth: 20,
                        progress: timerModel.intervalProgress,
                        color: accentColor,
                        backgroundColor: Color.gray.opacity(0.2),
                        rotationDegrees: -89.5
                    )
                    .accessibilityHidden(true)

                    ProgressRing(
                        size: 320,
                        lineWidth: 10,
                        progress: timerModel.overallProgress,
                        color: .primary,
                        backgroundColor: Color.gray.opacity(0.2),
                        rotationDegrees: -90.5
                    )
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("INTERVAL")
                            .font(.subheadline)
                            .foregroundStyle(.gray)

                        Text(timerModel.intervalTimeRemaining.formatted)
                            .font(
                                .system(
                                    size: 56,
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
                            RepsPill(text: makeCompletionText(), accentColor: .green)
                        } else if showHint {
                            Text(
                                timerModel.isRunning
                                    ? "Tap to pause ⸱ Hold to close"
                                    : "Tap to start ⸱ Hold to close"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.98))
                            )
                        } else {
                            RepsPill(text: makeRepsText(accent: accentColor), accentColor: accentColor)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }.onLongPressGesture(minimumDuration: 0.8) {
                    handleLongPress()
                }

                VStack(spacing: 8) {
                    Text("TOTAL")
                        .font(.subheadline)
                        .foregroundStyle(.gray)

                    Text(timerModel.totalTimeRemaining.formatted)
                        .font(
                            .system(size: 60, weight: .bold, design: .rounded)
                        )
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Total time")
                        .accessibilityValue(
                            timerModel.totalTimeRemaining.formatted
                        )
                }
            }
            // Konfetti Overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
            }
        }
        .onDisappear {
            timerModel.pause()
        }
        .onChange(of: timerModel.totalTimeRemaining) {
            oldValue,
            newValue in
            if oldValue > 0 && newValue == 0 {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showConfetti = false
                }
            }
        }
    }
}

// MARK: - Components
private struct ProgressRing: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let progress: Double
    let color: Color
    let backgroundColor: Color
    let rotationDegrees: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotationDegrees))
        }
        .frame(width: size, height: size)
    }
}

private struct RepsPill: View {
    let text: AttributedString
    let accentColor: Color

    var body: some View {
        Text(text)
            .font(.subheadline)
            .monospacedDigit()
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.25))
                    .stroke(
                        accentColor,
                        style: StrokeStyle(
                            lineWidth: 1,
                            lineCap: .round
                        )
                    )
            )
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

