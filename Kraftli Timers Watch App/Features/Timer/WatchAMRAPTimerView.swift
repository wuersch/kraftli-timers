//
//  WatchAMRAPTimerView.swift
//  Kraftli Timers Watch App
//
//  AMRAP timer view optimized for watchOS.
//  Tap to count rounds.
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

    /// Static timer kind — drives the accent color and the top-left glyph.
    private let timerKind: TimerKind = .amrap

    /// Live heart rate as an integer string, or "--" before the first sample.
    private var heartRateText: String {
        sessionManager.currentHeartRate.map { "\(Int($0))" } ?? "--"
    }

    /// Accumulated active calories as an integer string, or "--".
    private var caloriesText: String {
        sessionManager.activeCalories.map { "\(Int($0))" } ?? "--"
    }

    /// Lazily built coordinator that delegates shared workout lifecycle logic.
    private var coordinator: WatchWorkoutCoordinator {
        WatchWorkoutCoordinator(
            config: WatchWorkoutConfig(
                timerKind: .amrap,
                totalDuration: totalDuration,
                intervalCount: nil,
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
        Group {
            if countdown.isCountingDown {
                WatchCountdownView(countdown: countdown)
            } else {
                TabView {
                    metricsPage

                    WatchTimerControlsPage(
                        isRunning: timerModel.isRunning,
                        isCompleted: isCompleted,
                        onStop: {
                            coordinator.handleStop(timer: timerModel, countdown: countdown, dismiss: dismiss)
                        },
                        onPlayPause: {
                            coordinator.handlePlayPause(
                                timer: timerModel,
                                countdown: countdown,
                                isCompleted: isCompleted,
                                startTimerWithWorkoutSession: { coordinator.startTimerWithWorkoutSession(timer: timerModel) }
                            )
                        }
                    )
                }
                .tabViewStyle(.page)
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

    // MARK: - Metrics Page
    private var metricsPage: some View {
        ZStack(alignment: .topLeading) {
            // Metrics respect the safe area (sit below the clock), vertically
            // centered as a tight column. The whole column is tappable to count
            // rounds.
            VStack(alignment: .leading, spacing: -4) {
                // Total remaining
                WatchMetricRow(
                    value: isCompleted ? totalDuration.formatted : timerModel.totalTimeRemaining.formatted,
                    labelTop: "TOTAL",
                    valueColor: isCompleted ? .green : timerKind.color
                )
                // Rounds (the key tappable count)
                WatchMetricRow(
                    value: "\(timerModel.roundsCompleted)",
                    labelTop: "ROUNDS",
                    valueColor: isCompleted ? .green : timerKind.color
                )
                // Live heart rate
                WatchMetricRow(
                    value: heartRateText,
                    symbol: "heart.fill",
                    symbolColor: .red
                )
                // Active calories
                WatchMetricRow(
                    value: caloriesText,
                    labelTop: "ACTIVE",
                    labelBottom: "KCAL",
                    labelColor: .orange
                )

                if isCompleted {
                    Text("DONE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap counts rounds when running (not when completed). The metrics
                // page is only shown after the countdown, so no countdown guard needed.
                if timerModel.isRunning && !isCompleted {
                    timerModel.incrementRoundsCompleted()
                    syncService.sendTimerControl(.incrementRound) { result in
                        if case .failure(let error) = result {
                            Logger.timerSync.warning("sendTimerControl(.incrementRound) failed: \(error.localizedDescription)")
                        }
                    }
                }
            }

            // Glyph ignores the top inset so it rides up into the corner,
            // level with the clock.
            Image(timerKind.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(timerKind.color)
                .padding(.top, 18)
                .ignoresSafeArea(.container, edges: .top)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
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
