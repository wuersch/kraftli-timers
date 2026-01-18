//
//  WatchAMRAPTimerView.swift
//  Kraftli Timers Watch App
//
//  AMRAP timer view optimized for watchOS.
//  Tap to count rounds, Digital Crown also adjusts rounds.
//

import SwiftUI
import SwiftData

struct WatchAMRAPTimerView: View {
    // MARK: - Properties
    @State private var timerModel: AMRAPTimerModel
    @State private var crownValue: Double = 0
    @State private var hasLoggedWorkout = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let exerciseName: String
    private let totalDuration: TimeInterval

    // MARK: - Computed Properties
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

    private let accentColor: Color = .indigo

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        exerciseName: String = "AMRAP Workout"
    ) {
        self.totalDuration = totalDuration
        self.exerciseName = exerciseName
        self.timerModel = AMRAPTimerModel(
            totalDuration: totalDuration,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: WatchHapticFeedback()
        )
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringSize = size * 0.70
            let lineWidth = ringSize * 0.06
            
            ZStack { // centers children and will now fill the space
                VStack(spacing: 6) {
                    // Ring with center content
                    ZStack {
                        ProgressRing(
                            size: ringSize,
                            lineWidth: lineWidth,
                            progress: timerModel.progress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.3),
                            rotationDegrees: -90
                        )

                        // Center content
                        VStack(spacing: 2) {
                            Text("\(timerModel.roundsCompleted)")
                                .font(.system(size: ringSize * 0.28, weight: .bold, design: .rounded))
                                .foregroundStyle(isCompleted ? .gray : accentColor)
                                .monospacedDigit()
                                .contentTransition(.numericText())

                            if isCompleted {
                                Text("DONE")
                                    .font(.system(size: ringSize * 0.10, weight: .medium))
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    // Total time remaining
                    Text(timerModel.totalTimeRemaining.formatted)
                        .font(.system(size: ringSize * 0.16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap only counts rounds when running
            if timerModel.isRunning && !isCompleted {
                timerModel.incrementRoundsCompleted()
            }
        }
        .toolbar(.hidden)
        .onChange(of: isCompleted) { _, completed in
            if completed && !hasLoggedWorkout {
                logWorkout()
            }
        }
    }

    // MARK: - Workout Logging

    private func logWorkout() {
        hasLoggedWorkout = true

        let log = WorkoutLog(
            exerciseName: exerciseName,
            timerKind: .amrap,
            durationSeconds: totalDuration,
            roundsCompleted: timerModel.roundsCompleted
        )
        modelContext.insert(log)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        WatchAMRAPTimerView(totalDuration: 60)
    }
}
