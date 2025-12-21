//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI

// MARK: - EMOMTimerView
struct EMOMTimerView: View {
    // MARK: - Properties
    @State
    private var timerModel: EMOMTimerModel

    // MARK: - Initialization
    init(
        timerModel: EMOMTimerModel = EMOMTimerModel(
            totalReps: 100,
            totalMinutes: 20
        )
    ) {
        self.timerModel = timerModel
    }

    // MARK: - Styling
    private var accentColor: Color {
        timerModel.isIntervalWarning ? .orange : .blue
    }

    private var repsAttributedString: AttributedString {
        var attr = AttributedString(
            "\(timerModel.completedIntervals)/\(timerModel.totalIntervals) REPS"
        )
        // Color entire string with accentColor first
        attr.foregroundColor = accentColor
        // Then override the " REPS" segment to primary (exclude from accent coloring)
        if let repsRange = attr.range(of: " REPS") {
            attr[repsRange].foregroundColor = .primary
        }
        return attr
    }

    // MARK: - Actions
    private func handleTap() {
        if timerModel.isRunning {
            timerModel.pause()
        } else {
            timerModel.start()
        }
    }

    private func handleLongPress() {
        timerModel.reset()
    }

    // MARK: - Body
    var body: some View {

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

                    Text(timerModel.intervalTimeRemaining.mmSS)
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
                            timerModel.intervalTimeRemaining.mmSS
                        )

                    Text(repsAttributedString)
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

                Text(timerModel.totalTimeRemaining.mmSS)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Total time")
                    .accessibilityValue(timerModel.totalTimeRemaining.mmSS)
            }
        }

        .navigationTitle("Burpees ⸱ EMOM").navigationBarTitleDisplayMode(
            .inline
        )
        .onDisappear {
            timerModel.pause()
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

// MARK: - Preview
#Preview("EMOM Timer") {
    NavigationStack {
        EMOMTimerView(
            timerModel: EMOMTimerModel(totalReps: 100, totalMinutes: 20)
        )
    }
}
