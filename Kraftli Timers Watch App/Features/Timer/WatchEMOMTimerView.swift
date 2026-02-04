//
//  WatchEMOMTimerView.swift
//  Kraftli Timers Watch App
//
//  EMOM timer view optimized for watchOS.
//

import SwiftUI
import SwiftData
import HealthKit
import Combine
import os

struct WatchEMOMTimerView: View {
    // MARK: - Properties
    @State private var timerModel: EMOMTimerModel
    @State private var countdown = WatchCountdownCoordinator()
    @State private var hasLoggedWorkout = false
    @State private var cancellables = Set<AnyCancellable>()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Shared workout session manager injected from WorkoutAppDelegate.
    @Environment(WorkoutSessionManager.self) private var sessionManager

    private let exerciseName: String
    private let totalDuration: TimeInterval
    private let intervalDuration: TimeInterval

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

    private var accentColor: Color {
        timerModel.isIntervalWarning ? .orange : .blue
    }

    /// Lazily built coordinator that delegates shared workout lifecycle logic.
    private var coordinator: WatchWorkoutCoordinator {
        WatchWorkoutCoordinator(
            config: WatchWorkoutConfig(
                timerKind: .emom,
                totalDuration: totalDuration,
                intervalDuration: intervalDuration,
                exerciseName: exerciseName,
                displayOnly: displayOnly,
                scheduledStartTime: scheduledStartTime,
                correlationID: correlationID,
                makeWorkoutLog: { healthKitUUID in
                    WorkoutLog(
                        exerciseName: exerciseName,
                        timerKind: .emom,
                        durationSeconds: totalDuration,
                        repsCompleted: timerModel.totalIntervals,
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
        intervalDuration: TimeInterval = 60,
        exerciseName: String = "EMOM Workout",
        displayOnly: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        scheduledStartTime: Date? = nil,
        correlationID: UUID? = nil,
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.intervalDuration = intervalDuration
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.syncService = syncService
        self.scheduledStartTime = scheduledStartTime
        self.correlationID = correlationID
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

            ZStack {
                VStack(spacing: 6) {
                    ZStack {
                        // Rings - stay full during countdown
                        ProgressRing(
                            size: ringSize,
                            lineWidth: outerLineWidth,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.overallProgress,
                            color: Color.primary,
                            backgroundColor: Color.gray.opacity(0.3),
                            rotationDegrees: -90
                        )
                        ProgressRing(
                            size: ringSize * 0.85,
                            lineWidth: innerLineWidth,
                            progress: countdown.isCountingDown ? 1.0 : timerModel.intervalProgress,
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.3),
                            rotationDegrees: -90
                        )

                        // Center content - switches between countdown and normal display
                        if countdown.isCountingDown {
                            countdownCenterContent(ringSize: ringSize)
                        } else if isCompleted {
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
            .overlay(alignment: .topLeading) {
                // Hide interval counter during countdown
                if !countdown.isCountingDown {
                    Text("\(timerModel.completedIntervals)/\(timerModel.totalIntervals)")
                        .font(.system(size: ringSize * 0.11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary).padding(16)
                }
            }
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
        .toolbar(.hidden)
        .watchTimerLifecycle(
            timer: timerModel,
            sessionManager: sessionManager,
            onPause: { timerModel.pause() }
        )
        .onAppear {
            coordinator.setupControlSubscription(cancellables: &cancellables) { action in
                coordinator.handleRemoteControl(
                    action,
                    timer: timerModel,
                    countdown: countdown,
                    isCompleted: isCompleted,
                    dismiss: dismiss
                )
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
}

#Preview {
    NavigationStack {
        WatchEMOMTimerView(
            totalDuration: 60,
            intervalDuration: 12
        )
    }
}
