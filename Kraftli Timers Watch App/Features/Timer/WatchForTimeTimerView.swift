//
//  WatchForTimeTimerView.swift
//  Kraftli Timers Watch App
//
//  For Time timer view optimized for watchOS.
//  Counts up; tap to declare done.
//

import SwiftUI
import SwiftData

/// Runs a For Time workout through the Watch's `TimerSessionController` (ADR-006, ADR-0010).
///
/// Same flow as `WatchAMRAPTimerView`. A tap on the metrics page declares the workout
/// done via `done()`, which the owner records as a completion at the tap time. Pause and
/// End stay on the controls page.
struct WatchForTimeTimerView: View {
    // MARK: - Properties
    @State private var timerModel: ForTimeTimerModel
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

    /// Shared workout session manager owned by `WatchTimerRuntime`.
    @Environment(WorkoutSessionManager.self) private var sessionManager
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(WatchWorkoutStarter.self) private var starter

    private let exerciseName: String

    /// Identifies the workout on both devices; the iPhone's `WorkoutLog.id` for iPhone-started ones.
    private let workoutID: UUID

    /// True for workouts started on the iPhone: the iPhone writes the `WorkoutLog`.
    private let startedOnPhone: Bool

    /// Sends the HealthKit summary (`WorkoutSessionEndedMessage`) to the iPhone.
    private let syncService: WatchTimerSyncService

    // MARK: - Computed Properties
    private var isCompleted: Bool {
        timerModel.isCompleted
    }

    /// True while waiting to own (or follow) an iPhone-started workout.
    private var isStarting: Bool {
        timerSession.isAwaitingOwner && timerSession.workoutID == workoutID
    }

    /// Static timer kind — drives the accent color and the top-left glyph.
    private let timerKind: TimerKind = .forTime

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
            kind: .forTime,
            totalDuration: nil,
            intervalCount: nil,
            exerciseName: exerciseName,
            targetReps: timerModel.targetReps
        )
    }

    /// Ends the HealthKit session and logs or reports the workout.
    ///
    /// - Parameter finishTime: Captured when the workout completed, since the model may be
    ///   reset (End pressed) while the HealthKit session is still ending.
    private func coordinator(finishTime: TimeInterval) -> WatchWorkoutCoordinator {
        WatchWorkoutCoordinator(
            config: WatchWorkoutConfig(
                timerKind: .forTime,
                exerciseName: exerciseName,
                workoutID: workoutID,
                startedOnPhone: startedOnPhone,
                makeWorkoutLog: { [timerModel] healthKitUUID in
                    WorkoutLog(
                        exerciseName: exerciseName,
                        timerKind: .forTime,
                        durationSeconds: finishTime,
                        repsCompleted: timerModel.targetReps,
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
        targetReps: Int = TimerPreset.defaultForTimeReps,
        exerciseName: String = "For Time Workout",
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.exerciseName = exerciseName
        self.workoutID = workoutID
        self.startedOnPhone = startedOnPhone
        self.syncService = syncService
        self.timerModel = ForTimeTimerModel(
            targetReps: targetReps,
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

    /// Declares the workout done while it runs.
    private func declareDone() {
        guard timerModel.isRunning, !isCompleted, timerSession.workoutID == workoutID else { return }
        timerSession.done()
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
        coordinator(finishTime: timerModel.finishTime)
            .stopAndCleanup(timer: timerModel, countdown: countdown, dismiss: dismiss)
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
    /// A done declared on the iPhone arrives as `.completed` and is handled via `didComplete`.
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
            sessionManager: sessionManager
        )
        .onAppear {
            // Run setup exactly once (see WatchAMRAPTimerView).
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
            guard didComplete && !hasLoggedWorkout else { return }
            hasLoggedWorkout = true
            let finishTime = timerModel.finishTime
            Task {
                await coordinator(finishTime: finishTime).handleWorkoutCompleted(modelContext: modelContext)
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
            // The whole column is tappable to declare done.
            VStack(alignment: .leading, spacing: -4) {
                // Elapsed time, counting up; the finish time once done
                WatchMetricRow(
                    value: timerModel.elapsedTime.formatted,
                    labelTop: isCompleted ? "FINISH" : "ELAPSED",
                    valueColor: isCompleted ? .green : timerKind.color
                )
                // Target reps
                WatchMetricRow(
                    value: "\(timerModel.targetReps)",
                    labelTop: "REPS",
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
                declareDone()
            }
            .accessibilityAddTraits(isCompleted ? [] : .isButton)
            .accessibilityHint(isCompleted ? "" : "Tap when done")

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
}

#Preview {
    NavigationStack {
        WatchForTimeTimerView(targetReps: 50)
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
