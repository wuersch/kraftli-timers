//
//  WatchEMOMTimerView.swift
//  Kraftli Timers Watch App
//
//  EMOM timer view optimized for watchOS.
//

import SwiftUI
import SwiftData
import Combine

struct WatchEMOMTimerView: View {
    // MARK: - Properties
    @State private var timerModel: EMOMTimerModel
    @State private var hasLoggedWorkout = false
    @State private var cancellables = Set<AnyCancellable>()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let exerciseName: String
    private let totalDuration: TimeInterval

    /// When true, skip workout logging (timer was started from iPhone).
    private let displayOnly: Bool

    /// Service for syncing timer controls with iPhone (nil for standalone timers).
    private let syncService: WatchTimerSyncService?

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
        intervalDuration: TimeInterval = 60,
        exerciseName: String = "EMOM Workout",
        displayOnly: Bool = false,
        syncService: WatchTimerSyncService? = nil,
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = WatchHapticFeedback()
    ) {
        self.totalDuration = totalDuration
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.syncService = syncService
        self.timerModel = EMOMTimerModel(
            totalDuration: totalDuration,
            intervalDuration: intervalDuration,
            timerProvider: timerProvider,
            feedbackProvider: feedbackProvider
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
                        handleStop()
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
                        handlePlayPause()
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
        .watchTimerLifecycle(timer: timerModel)
        .onAppear {
            setupControlSubscription()
        }
        .onChange(of: isCompleted) { _, completed in
            if completed && !hasLoggedWorkout && !displayOnly {
                hasLoggedWorkout = true  // Set immediately to prevent race condition
                logWorkout()
            }
        }
    }

    // MARK: - Timer Control

    private func handlePlayPause() {
        if timerModel.isRunning {
            timerModel.pause()
            syncService?.sendTimerControl(.pause, completion: nil)
        } else {
            timerModel.start()
            syncService?.sendTimerControl(.play, completion: nil)
        }
    }

    private func handleStop() {
        timerModel.reset()
        syncService?.sendTimerControl(.stop, completion: nil)
        dismiss()
    }

    /// Sets up subscription to receive control messages from iPhone.
    private func setupControlSubscription() {
        syncService?.timerControlReceived
            .receive(on: DispatchQueue.main)
            .sink { [self] action in
                handleRemoteControl(action)
            }
            .store(in: &cancellables)
    }

    /// Handles control messages received from iPhone.
    private func handleRemoteControl(_ action: TimerControlAction) {
        switch action {
        case .play:
            if !timerModel.isRunning {
                timerModel.start()
            }
        case .pause:
            if timerModel.isRunning {
                timerModel.pause()
            }
        case .stop:
            timerModel.reset()
            dismiss()
        case .incrementRound:
            break  // Not applicable to EMOM timers
        }
    }

    // MARK: - Workout Logging

    private func logWorkout() {
        let log = WorkoutLog(
            exerciseName: exerciseName,
            timerKind: .emom,
            durationSeconds: totalDuration,
            repsCompleted: timerModel.totalIntervals
        )
        modelContext.insert(log)
        try? modelContext.save()
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
