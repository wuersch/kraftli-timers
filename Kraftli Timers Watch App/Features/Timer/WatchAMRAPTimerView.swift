//
//  WatchAMRAPTimerView.swift
//  Kraftli Timers Watch App
//
//  AMRAP timer view optimized for watchOS.
//  Tap to count rounds, Digital Crown also adjusts rounds.
//

import SwiftUI
import SwiftData
import Combine

struct WatchAMRAPTimerView: View {
    // MARK: - Properties
    @State private var timerModel: AMRAPTimerModel
    @State private var crownValue: Double = 0
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

    private let accentColor: Color = .indigo

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        exerciseName: String = "AMRAP Workout",
        displayOnly: Bool = false,
        syncService: WatchTimerSyncService? = nil,
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = WatchHapticFeedback()
    ) {
        self.totalDuration = totalDuration
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.syncService = syncService
        self.timerModel = AMRAPTimerModel(
            totalDuration: totalDuration,
            timerProvider: timerProvider,
            feedbackProvider: feedbackProvider
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
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap only counts rounds when running
            if timerModel.isRunning && !isCompleted {
                timerModel.incrementRoundsCompleted()
                syncService?.sendTimerControl(.incrementRound, completion: nil)
            }
        }
        .toolbar(.hidden)
        .watchTimerLifecycle(timer: timerModel, onPause: { timerModel.pause() })
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
            if timerModel.isRunning && !isCompleted {
                timerModel.incrementRoundsCompleted()
            }
        }
    }

    // MARK: - Workout Logging

    private func logWorkout() {
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
