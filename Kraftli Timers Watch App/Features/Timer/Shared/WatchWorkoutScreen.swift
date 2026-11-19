//
//  WatchWorkoutScreen.swift
//  Kraftli Timers Watch App
//
//  The screen every timer kind runs on, on the Watch: it starts or joins the workout,
//  follows the timer session, shows the countdown, the controls page and the metrics
//  page. The kinds (EMOM, AMRAP, For Time) plug in their metric rows.
//

import SwiftUI
import SwiftData

/// What a tap on the metrics page does while the workout is running.
enum WatchMetricsTap {
    /// AMRAP: count a round.
    case countRound
    /// For Time: declare the workout done.
    case declareDone
}

/// Runs a workout through the Watch's `TimerSessionController` (ADR-006).
///
/// - **Watch-started:** the Watch owns the workout from the first moment.
/// - **iPhone-started:** `WatchWorkoutStarter` has already received the request. The Watch
///   owns the workout once its HealthKit session runs, or follows the iPhone if the iPhone
///   took over first.
///
/// Either way, every rendered state goes to `model.apply(_:)`, and the buttons become
/// controller actions. The HealthKit session pauses and resumes with the model's
/// `isRunning` (`watchTimerLifecycle`), which itself comes from the state.
///
/// Like the iPhone's `TimerScreen`, this is a container view: a kind passes its metric
/// rows as a `@ViewBuilder` closure and the screen places them above the heart rate.
struct WatchWorkoutScreen<Model: TimerStateRendering, KindRows: View>: View {
    // MARK: - Properties
    @State private var countdown = CountdownCoordinator()
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

    /// The kind's timer model. Owned by the kind's view (`@State` there).
    let model: Model
    /// The workout to start (Watch-started) or the one being joined (iPhone-started).
    let config: TimerConfig

    /// Identifies the workout on both devices; the iPhone's `WorkoutLog.id` for iPhone-started ones.
    let workoutID: UUID

    /// True for workouts started on the iPhone: the iPhone writes the `WorkoutLog`.
    let startedOnPhone: Bool

    /// Sends the HealthKit summary (`WorkoutSessionEndedMessage`) to the iPhone.
    let syncService: WatchTimerSyncService

    /// What a tap on the metrics page does while running; nil for a kind without one.
    let metricsTap: WatchMetricsTap?

    /// Creates the `WorkoutLog` of the completed workout (without its HealthKit UUID).
    /// Called the moment the workout completes, for Watch-started workouts only.
    let makeWorkoutLog: () -> WorkoutLog

    /// The kind's own metric rows, shown above heart rate and calories.
    @ViewBuilder let kindRows: () -> KindRows

    // MARK: - Computed Properties
    private var isCompleted: Bool { model.isCompleted }

    /// Drives the accent color and the top-left glyph.
    private var timerKind: TimerKind { config.kind }

    /// True while waiting to own (or follow) an iPhone-started workout, or for the
    /// athlete's answer about Apple Health access before the first Watch-started one.
    private var isStarting: Bool {
        (timerSession.isAwaitingOwner && timerSession.workoutID == workoutID)
            || starter.workoutAwaitingHealthAccess == workoutID
    }

    /// True when this workout is a step of a training session run on the iPhone. Its end
    /// is not the session's end: the Health session stays with the run, nothing is
    /// logged here, and the screen closes by itself (ADR-0012).
    private var isSessionStep: Bool {
        starter.isSessionStep(workoutID)
    }

    /// Live heart rate as an integer string, or "--" before the first sample.
    private var heartRateText: String {
        sessionManager.currentHeartRate.map { "\(Int($0))" } ?? "--"
    }

    /// Accumulated active calories as an integer string, or "--".
    private var caloriesText: String {
        sessionManager.activeCalories.map { "\(Int($0))" } ?? "--"
    }

    /// Ends the HealthKit session and logs or reports the workout.
    private var coordinator: WatchWorkoutCoordinator {
        WatchWorkoutCoordinator(
            timerKind: timerKind,
            workoutID: workoutID,
            startedOnPhone: startedOnPhone,
            syncService: syncService,
            sessionManager: sessionManager
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

    /// A tap on the metrics page: the kind's action, while the workout runs.
    private func metricsTapped(_ tap: WatchMetricsTap) {
        guard model.isRunning, !isCompleted, timerSession.workoutID == workoutID else { return }
        switch tap {
        case .countRound: timerSession.incrementRound()
        case .declareDone: timerSession.done()
        }
    }

    /// The End button: stop the workout on both devices, then close.
    private func endWorkout() {
        guard !isEnding else { return }
        timerSession.stop()
        tearDown()
    }

    /// Ends the HealthKit session, records or reports the workout and closes the screen.
    ///
    /// A workout stopped early is judged by `EarlyStop` first, while the session still
    /// holds its state: too short, and the Health workout is discarded instead of saved;
    /// long enough, and a Watch-started workout gets its history entry here (the iPhone
    /// writes the entry of a workout it started).
    private func tearDown() {
        isEnding = true
        guard !isSessionStep else {
            // Only the step ends. The iPhone records it and reports the session's
            // progress; `WatchSessionFollower` pauses or ends the Health session from that.
            countdown.cancelCountdown()
            model.reset()
            dismiss()
            starter.workoutEnded()
            return
        }
        var stoppedLog: WorkoutLog?
        if timerSession.workoutID == workoutID, let state = timerSession.renderedState {
            switch EarlyStop(of: state, at: Date()) {
            case .discard:
                sessionManager.discardSession()
            case .record(let activeTime, let reps, let rounds) where !startedOnPhone:
                stoppedLog = WorkoutLog(
                    exerciseName: config.exerciseName,
                    timerKind: timerKind,
                    durationSeconds: activeTime,
                    repsCompleted: reps,
                    roundsCompleted: rounds,
                    stoppedEarly: true
                )
            case .record, nil:
                break
            }
        }
        coordinator.stopAndCleanup(
            timer: model,
            countdown: countdown,
            stoppedLog: stoppedLog,
            modelContext: modelContext,
            dismiss: dismiss
        )
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
        guard case .stopped = finish, !isEnding else { return }
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
                        isRunning: model.isRunning,
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
            timer: model,
            sessionManager: sessionManager,
            isEnding: isEnding
        )
        .onAppear {
            // Run setup exactly once. onAppear can fire again when the view
            // re-appears (e.g. starting the HKWorkoutSession promotes the app
            // to the foreground workout scene).
            guard !didStart else { return }
            didStart = true

            timerSession.onRenderedStateChange = { [model] state in
                model.apply(state)
            }
            if startedOnPhone {
                // The request was handled before this view existed; catch up with its state.
                if let state = timerSession.renderedState, timerSession.workoutID == workoutID {
                    model.apply(state)
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
            model.reset()
            dismiss()
        }
        .onChange(of: model.didComplete) { _, didComplete in
            // Key off the model's explicit completion signal, not isCompleted — a pause
            // clamp must not log/celebrate a workout the user just paused.
            guard didComplete && !hasLoggedWorkout else { return }
            hasLoggedWorkout = true
            if isSessionStep {
                // Publish the completion before letting go of the step, then close: the
                // session's next screen is the iPhone's.
                timerSession.checkCompletion()
                if !isEnding { tearDown() }
                return
            }
            // Build the log now, while the model still holds the result: pressing End
            // while the HealthKit save below is pending resets the model.
            let log = startedOnPhone ? nil : makeWorkoutLog()
            Task {
                await coordinator.handleWorkoutCompleted(log: log, modelContext: modelContext)
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
                kindRows()

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
            .modifier(MetricsTapGesture(tap: metricsTap, isCompleted: isCompleted, action: metricsTapped))

            // Glyph ignores the top inset so it rides up into the corner,
            // level with the clock.
            Image(timerKind.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(timerKind.color)
                .padding(.top, 18)
                .ignoresSafeArea(.container, edges: .top)
                // Taps on the glyph belong to the metrics column underneath.
                .allowsHitTesting(metricsTap == nil)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Metrics Tap Gesture

/// Makes the whole metrics column tappable for the kinds whose tap means something.
private struct MetricsTapGesture: ViewModifier {
    let tap: WatchMetricsTap?
    let isCompleted: Bool
    let action: (WatchMetricsTap) -> Void

    func body(content: Content) -> some View {
        switch tap {
        case nil:
            content
        case .countRound:
            content
                .contentShape(Rectangle())
                .onTapGesture { action(.countRound) }
        case .declareDone:
            content
                .contentShape(Rectangle())
                .onTapGesture { action(.declareDone) }
                .accessibilityAddTraits(isCompleted ? [] : .isButton)
                .accessibilityHint(isCompleted ? "" : "Tap when done")
        }
    }
}
