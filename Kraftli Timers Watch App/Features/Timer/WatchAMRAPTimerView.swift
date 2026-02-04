//
//  WatchAMRAPTimerView.swift
//  Kraftli Timers Watch App
//
//  AMRAP timer view optimized for watchOS.
//  Tap to count rounds, Digital Crown also adjusts rounds.
//

import SwiftUI
import SwiftData
import HealthKit
import Combine
import os

struct WatchAMRAPTimerView: View {
    // MARK: - Properties
    @State private var timerModel: AMRAPTimerModel
    @State private var countdown = WatchCountdownCoordinator()
    @State private var crownValue: Double = 0
    @State private var hasLoggedWorkout = false
    @State private var cancellables = Set<AnyCancellable>()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Shared workout session manager injected from WorkoutAppDelegate.
    @Environment(WorkoutSessionManager.self) private var sessionManager

    private let exerciseName: String
    private let totalDuration: TimeInterval

    /// When true, skip workout logging (timer was started from iPhone).
    private let displayOnly: Bool

    /// Service for syncing timer controls with iPhone.
    private let syncService: WatchTimerSyncService

    /// Scheduled start time from iPhone for synchronized countdown.
    private let scheduledStartTime: Date?

    /// Correlation ID from iPhone's StartTimerMessage, echoed back in
    /// WorkoutSessionEndedMessage for exact WorkoutLog matching.
    private let correlationID: UUID?

    // MARK: - Computed Properties
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

    private let accentColor: Color = .indigo

    /// Lazily built coordinator that delegates shared workout lifecycle logic.
    private var coordinator: WatchWorkoutCoordinator {
        WatchWorkoutCoordinator(
            config: WatchWorkoutConfig(
                timerKind: .amrap,
                totalDuration: totalDuration,
                intervalDuration: nil,
                exerciseName: exerciseName,
                displayOnly: displayOnly,
                scheduledStartTime: scheduledStartTime,
                correlationID: correlationID,
                makeWorkoutLog: { healthKitUUID in
                    WorkoutLog(
                        exerciseName: exerciseName,
                        timerKind: .amrap,
                        durationSeconds: totalDuration,
                        roundsCompleted: timerModel.roundsCompleted,
                        healthKitWorkoutUUID: healthKitUUID
                    )
                }
            ),
            syncService: syncService,
            sessionManager: sessionManager
        )
    }

    // MARK: - Initialization
    init(
        totalDuration: TimeInterval = 20 * 60,
        exerciseName: String = "AMRAP Workout",
        displayOnly: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        scheduledStartTime: Date? = nil,
        correlationID: UUID? = nil,
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.syncService = syncService
        self.scheduledStartTime = scheduledStartTime
        self.correlationID = correlationID
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

            ZStack {
                VStack(spacing: 6) {
                    // Ring with center content
                    ZStack {
                        // Ring - stays full during countdown
                        ProgressRing(
                            size: ringSize,
                            lineWidth: lineWidth,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.progress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.3),
                            rotationDegrees: -90
                        )

                        // Center content - switches between countdown and normal display
                        if countdown.isCountingDown {
                            countdownCenterContent(ringSize: ringSize)
                        } else {
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
                    }

                    // Bottom section - ZStack maintains consistent height
                    ZStack {
                        // Normal total time (always present for layout)
                        Text(timerModel.totalTimeRemaining.formatted)
                            .font(.system(size: ringSize * 0.16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .opacity(countdown.isCountingDown ? 0 : 1)

                        // "Get ready" text (shown during countdown)
                        Text("Get ready")
                            .font(.system(size: ringSize * 0.13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .opacity(countdown.isCountingDown ? 1 : 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .bottom) {
                // Hide controls during countdown
                if !countdown.isCountingDown {
                    HStack {
                        Button {
                            coordinator.handleStop(timer: timerModel, countdown: countdown, dismiss: dismiss)
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
                            coordinator.handlePlayPause(
                                timer: timerModel,
                                countdown: countdown,
                                isCompleted: isCompleted,
                                startTimerWithWorkoutSession: { coordinator.startTimerWithWorkoutSession(timer: timerModel) }
                            )
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
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap only counts rounds when running (and not during countdown)
            if timerModel.isRunning && !isCompleted && !countdown.isCountingDown {
                timerModel.incrementRoundsCompleted()
                syncService.sendTimerControl(.incrementRound) { result in
                    if case .failure(let error) = result {
                        Logger.timerSync.warning("sendTimerControl(.incrementRound) failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        .toolbar(.hidden)
        .watchTimerLifecycle(
            timer: timerModel,
            sessionManager: sessionManager,
            onPause: { timerModel.pause() }
        )
        .onAppear {
            coordinator.setupControlSubscription(cancellables: &cancellables) { action in
                handleRemoteControl(action)
            }
            coordinator.startCountdownIfNeeded(countdown: countdown) {
                coordinator.startTimerWithWorkoutSession(timer: timerModel)
            }
        }
        .onChange(of: sessionManager.sessionState) { _, newState in
            coordinator.reconcileSessionState(
                newState,
                timer: timerModel,
                isCompleted: isCompleted,
                isCountingDown: countdown.isCountingDown
            )
        }
        .onChange(of: isCompleted) { _, completed in
            guard completed && !hasLoggedWorkout else { return }
            hasLoggedWorkout = true
            Task {
                await coordinator.handleWorkoutCompleted(modelContext: modelContext)
            }
        }
    }

    // MARK: - Countdown Center Content
    @ViewBuilder
    private func countdownCenterContent(ringSize: CGFloat) -> some View {
        let displayText = countdown.countdownValue.map { $0 > 0 ? "\($0)" : "GO" } ?? ""
        let textColor: Color = .primary

        Text(displayText)
            .font(.system(size: ringSize * 0.35, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .contentTransition(.numericText())
            .id(countdown.countdownValue)
    }

    // MARK: - Remote Control (AMRAP-specific)

    /// Handles control messages from iPhone. Delegates to coordinator for common
    /// actions, adds AMRAP-specific `.incrementRound` handling.
    private func handleRemoteControl(_ action: TimerControlAction) {
        switch action {
        case .incrementRound:
            if timerModel.isRunning && !isCompleted {
                timerModel.incrementRoundsCompleted()
            }
        default:
            coordinator.handleRemoteControl(
                action,
                timer: timerModel,
                countdown: countdown,
                isCompleted: isCompleted,
                dismiss: dismiss
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchAMRAPTimerView(totalDuration: 60)
    }
}
