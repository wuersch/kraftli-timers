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
    @State private var page: WorkoutPage = .metrics
    @State private var didStart = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Shared workout session manager injected from WorkoutAppDelegate.
    @Environment(WorkoutSessionManager.self) private var sessionManager

    private let exerciseName: String
    private let totalDuration: TimeInterval
    private let intervalCount: Int

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
    private let timerKind: TimerKind = .emom

    /// Interval row color: orange in the warning window, green when done.
    private var intervalColor: Color {
        if isCompleted { return .green }
        return timerModel.isIntervalWarning ? .orange : timerKind.color
    }

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
                timerKind: .emom,
                totalDuration: totalDuration,
                intervalCount: intervalCount,
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
        intervalCount: Int = 20,
        exerciseName: String = "EMOM Workout",
        displayOnly: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        scheduledStartTime: Date? = nil,
        correlationID: UUID? = nil,
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.intervalCount = intervalCount
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.syncService = syncService
        self.scheduledStartTime = scheduledStartTime
        self.correlationID = correlationID
        self.timerModel = EMOMTimerModel(
            totalDuration: totalDuration,
            intervalCount: intervalCount,
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
                TabView(selection: $page) {
                    // Controls sit to the LEFT (Apple Workout parity); the
                    // selection below makes metrics the page shown on launch.
                    WatchTimerControlsPage(
                        isRunning: timerModel.isRunning,
                        isCompleted: isCompleted,
                        onStop: {
                            coordinator.handleStop(timer: timerModel, countdown: countdown, dismiss: dismiss)
                        },
                        onPlayPause: {
                            let isResuming = !timerModel.isRunning && !isCompleted
                            coordinator.handlePlayPause(
                                timer: timerModel,
                                countdown: countdown,
                                isCompleted: isCompleted,
                                startTimerWithWorkoutSession: { coordinator.startTimerWithWorkoutSession(timer: timerModel) }
                            )
                            // Resuming brings the running timer back into view.
                            if isResuming { withAnimation { page = .metrics } }
                        }
                    )
                    .tag(WorkoutPage.controls)

                    metricsPage
                        .tag(WorkoutPage.metrics)
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
            // Run setup exactly once. onAppear can fire again when the view
            // re-appears (e.g. starting the HKWorkoutSession promotes the app
            // to the foreground workout scene). Without this guard the
            // standalone auto-start would relaunch its `now+3` countdown on
            // every re-appear — looping forever, never reaching the timer — and
            // would also stack duplicate control subscriptions.
            guard !didStart else { return }
            didStart = true

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
                isCountingDown: countdown.isCountingDown,
                transitionDate: sessionManager.lastTransitionDate ?? Date()
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
            // centered as a tight column.
            VStack(alignment: .leading, spacing: -4) {
                // Total remaining
                WatchMetricRow(
                    value: isCompleted ? totalDuration.formatted : timerModel.totalTimeRemaining.formatted,
                    labelTop: "TOTAL",
                    valueColor: isCompleted ? .green : timerKind.color
                )
                // Interval remaining
                WatchMetricRow(
                    value: timerModel.intervalTimeRemaining.formatted,
                    labelTop: "INTERVAL",
                    valueColor: intervalColor
                )
                // Reps done / total
                WatchMetricRow(
                    value: "\(timerModel.completedIntervals)/\(timerModel.totalIntervals)",
                    labelTop: "REPS"
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

            // Glyph ignores the top inset so it rides up into the corner,
            // level with the clock.
            Image(timerKind.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(timerKind.color)
                .padding(.top, 18)
                .ignoresSafeArea(.container, edges: .top)
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    NavigationStack {
        WatchEMOMTimerView(
            totalDuration: 60,
            intervalCount: 5
        )
    }
}
