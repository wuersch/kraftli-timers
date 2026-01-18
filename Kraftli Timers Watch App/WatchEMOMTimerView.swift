//
//  WatchEMOMTimerView.swift
//  Kraftli Timers Watch App
//
//  EMOM timer view optimized for watchOS.
//

import SwiftUI

struct WatchEMOMTimerView: View {
    // MARK: - Properties
    @State private var timerModel: EMOMTimerModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

    private var accentColor: Color {
        timerModel.isIntervalWarning ? .orange : .blue
    }

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        intervalDuration: TimeInterval = 60
    ) {
        self.timerModel = EMOMTimerModel(
            totalDuration: totalDuration,
            intervalDuration: intervalDuration,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: WatchHapticFeedback()
        )
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringSize = size * 0.7
            let outerLineWidth = ringSize * 0.035
            let innerLineWidth = ringSize * 0.06
            
            ZStack { // centers children and will now fill the space
                VStack(spacing: 6) {
                    ZStack {
                        ProgressRing(
                            size: ringSize,
                            lineWidth: outerLineWidth,
                            progress: timerModel.overallProgress,
                            color: Color.primary,
                            backgroundColor: Color.gray.opacity(0.3),
                            rotationDegrees: -90
                        )
                        ProgressRing(
                            size: ringSize * 0.85,
                            lineWidth: innerLineWidth,
                            progress: timerModel.intervalProgress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.3),
                            rotationDegrees: -90
                        )

                        if isCompleted {
                            Text("DONE")
                                .font(.system(size: ringSize * 0.22, weight: .medium))
                                .foregroundStyle(.green)
                        } else {
                            Text(timerModel.intervalTimeRemaining.formatted)
                                .font(.system(size: ringSize * 0.22, weight: .semibold, design: .rounded))
                                .foregroundStyle(accentColor)
                                .monospacedDigit()
                        }
                        
                    }
                    // Total time remaining
                    Text(timerModel.totalTimeRemaining.formatted)
                        .font(.system(size: ringSize * 0.16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .topLeading) {
                Text("\(timerModel.completedIntervals)/\(timerModel.totalIntervals)")
                    .font(.system(size: ringSize * 0.11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary).padding(16)
            }
            .overlay(alignment: .bottom) {
                HStack {
                    Button {
                        timerModel.reset()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        if timerModel.isRunning {
                            timerModel.pause()
                        } else {
                            timerModel.start()
                        }
                    } label: {
                        Image(systemName: timerModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isCompleted ? .gray : .primary)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden)
    }
}

#Preview {
    NavigationStack {
        WatchEMOMTimerView(
            totalDuration: 60,
            intervalDuration: 12
        )
    }
}
