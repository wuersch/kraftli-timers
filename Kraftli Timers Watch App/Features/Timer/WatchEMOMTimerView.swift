//
//  WatchEMOMTimerView.swift
//  Kraftli Timers Watch App
//
//  EMOM timer view optimized for watchOS.
//

import SwiftUI
import SwiftData

/// Runs an EMOM workout through the Watch's `TimerSessionController` (ADR-006).
///
/// - **Watch-started:** the Watch owns the workout from the first moment.
/// - **iPhone-started:** `WatchWorkoutStarter` has already received the request. The Watch
///   owns the workout once its HealthKit session runs, or follows the iPhone if the iPhone
///   took over first.
///
/// Either way, every rendered state goes to `timerModel.apply(_:)`, and the buttons become
/// controller actions. The HealthKit session pauses and resumes with the model's
/// `isRunning` (`watchTimerLifecycle`), which itself comes from the state.
struct WatchEMOMTimerView: View {
    // MARK: - Properties
    @State private var timerModel: EMOMTimerModel
    @State private var countdown = WatchCountdownCoordinator()
    @State private var hasLoggedWorkout = false
    @State private var page: WorkoutPage = .metrics
    @State private var didStart = false
    /// The start date the countdown was begun for, so the workout counts down once.
    @State private var countdownStartDate: Date?
    /// Set once this view tears its workout down, so its own stop isn't handled twice.
    @State private var isEnding = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Shared workout session manager injected from WorkoutAppDelegate.
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(WatchWorkoutStarter.self) private var starter

    private let exerciseName: String
    private let totalDuration: TimeInterval
    private let intervalCount: Int

    /// Identifies the workout on both devices; the iPhone's `WorkoutLog.id` for iPhone-started ones.
    private let workoutID: UUID

    /// True for workouts started on the iPhone: the iPhone writes the `WorkoutLog`.
    private let startedOnPhone: Bool

    /// Sends the HealthKit summary (`WorkoutSessionEndedMessage`) to the iPhone.
    private let syncService: WatchTimerSyncService

    // MARK: - Computed Properties
    private var isCompleted: Bool {
        timerModel.totalTimeRemaining <= 0
    }

    /// True while waiting to own (or follow) an iPhone-started workout.
    private var isStarting: Bool {
        timerSession.isAwaitingOwner && timerSession.workoutID == workoutID
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

    private var config: TimerConfig {
        TimerConfig(
            timerKindRaw: TimerKind.emom.rawValue,
            totalDuration: totalDuration,
            intervalCount: intervalCount,
            exerciseName: exerciseName
        )
    }

    /// Ends the HealthKit session and logs or reports the workout.
    private var coordinator: WatchWorkoutCoordinator {
        WatchWorkoutCoordinator(
            config: WatchWorkoutConfig(
                timerKind: .emom,
                totalDuration: totalDuration,
                exerciseName: exerciseName,
                workoutID: workoutID,
                startedOnPhone: startedOnPhone,
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
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.intervalCount = intervalCount
        self.exerciseName = exerciseName
        self.workoutID = workoutID
        self.startedOnPhone = startedOnPhone
        self.syncService = syncService
        self.timerModel = EMOMTimerModel(
            totalDuration: totalDuration,
            intervalCount: intervalCount,
            timerProvider: timerProvider,
            feedbackProvider: feedbackProvider
        )
    }

    // MARK: - Actions

    private func togglePause() {
        guard !countdown.isCountingDown, let state = timerSession.renderedState,
              timerSession.workoutID == workoutID, !isCompleted else { return }
        if state.isPaused {
            timerSession.resume()
            // Resuming brings the running timer back into view.
            withAnimation { page = .metrics }
        } else {
            timerSession.pause()
        }
    }

    /// The End button: stop the workout on both devices, then close.
    private func endWorkout() {
        guard !isEnding else { return }
        timerSession.stop()
        tearDown()
    }

    /// Ends (and saves) the HealthKit session, reports to the iPhone and closes the screen.
    private func tearDown() {
        isEnding = true
        coordinator.stopAndCleanup(timer: timerModel, countdown: countdown, dismiss: dismiss)
        starter.workoutEnded()
    }

    /// Shows the 3-2-1-GO countdown toward the shared start date. The model already
    /// follows the state; the countdown only displays (a tap hides it early).
    private func beginCountdown(until startDate: Date) {
        guard countdownStartDate == nil else { return }
        countdownStartDate = startDate
        countdown.startCountdown(scheduledStartTime: startDate)
    }

    /// The workout was stopped elsewhere (the iPhone, or a stop sent while starting).
    private func finishChanged(_ finish: TimerState.Finish?) {
        guard case .stopped(let stoppedAt) = finish, !isEnding else { return }
        if let startDate = timerSession.renderedState?.startDate, stoppedAt <= startDate {
            // Cancelled before the workout began: nothing worth saving to Health.
            sessionManager.discardSession()
        }
        tearDown()
    }

    // MARK: - Body
    var body: some View {
        Group {
            if isStarting {
                startingView
            } else if countdown.isCountingDown {
                WatchCountdownView(countdown: countdown)
            } else {
                TabView(selection: $page) {
                    // Controls sit to the LEFT (Apple Workout parity); the
                    // selection below makes metrics the page shown on launch.
                    WatchTimerControlsPage(
                        isRunning: timerModel.isRunning,
                        isCompleted: isCompleted,
                        onStop: { endWorkout() },
                        onPlayPause: { togglePause() }
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
            onPause: { timerSession.pause() }
        )
        .onAppear {
            // Run setup exactly once. onAppear can fire again when the view
            // re-appears (e.g. starting the HKWorkoutSession promotes the app
            // to the foreground workout scene).
            guard !didStart else { return }
            didStart = true

            timerSession.onRenderedStateChange = { [timerModel] state in
                timerModel.apply(state)
            }
            if startedOnPhone {
                // The request was handled before this view existed; catch up with its state.
                if let state = timerSession.renderedState, timerSession.workoutID == workoutID {
                    timerModel.apply(state)
                    beginCountdown(until: state.startDate)
                }
            } else {
                starter.startOnWatch(workoutID: workoutID, config: config)
            }
        }
        // The owner's first snapshot fixes the start date: count down toward it.
        .onChange(of: timerSession.renderedState?.startDate) { _, startDate in
            guard let startDate, timerSession.workoutID == workoutID else { return }
            beginCountdown(until: startDate)
        }
        .onChange(of: timerSession.renderedState?.finish) { _, finish in
            finishChanged(finish)
        }
        .onChange(of: timerSession.workoutID) { _, newID in
            // The starter gave up on this workout (no owner in time): close the screen.
            guard newID == nil, !isEnding else { return }
            isEnding = true
            countdown.cancelCountdown()
            timerModel.reset()
            dismiss()
        }
        .onChange(of: timerModel.didComplete) { _, didComplete in
            // Key off the model's explicit completion signal, not isCompleted (totalTimeRemaining
            // <= 0) — a pause(at:) clamp must not log/celebrate a workout the user just paused.
            guard didComplete && !hasLoggedWorkout else { return }
            hasLoggedWorkout = true
            Task {
                await coordinator.handleWorkoutCompleted(modelContext: modelContext)
            }
        }
    }

    // MARK: - Starting View
    private var startingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Starting…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                // Reps: the interval currently in progress / total, matching the
                // iPhone's 1-based `currentInterval` display (starts at 1/N, ends N/N).
                WatchMetricRow(
                    value: "\(timerModel.currentInterval)/\(timerModel.totalIntervals)",
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
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
