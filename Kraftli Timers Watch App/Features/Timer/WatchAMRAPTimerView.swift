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

    /// Service for syncing timer controls with iPhone (nil for standalone timers).
    private let syncService: WatchTimerSyncService?

    /// Scheduled start time from iPhone for synchronized countdown.
    private let scheduledStartTime: Date?

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
        scheduledStartTime: Date? = nil,
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.exerciseName = exerciseName
        self.displayOnly = displayOnly
        self.syncService = syncService
        self.scheduledStartTime = scheduledStartTime
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
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap only counts rounds when running (and not during countdown)
            if timerModel.isRunning && !isCompleted && !countdown.isCountingDown {
                timerModel.incrementRoundsCompleted()
                syncService?.sendTimerControl(.incrementRound) { result in
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
            setupControlSubscription()
            startCountdownIfNeeded()
        }
        .onChange(of: sessionManager.sessionState) { _, newState in
            reconcileSessionState(newState)
        }
        .onChange(of: isCompleted) { _, completed in
            guard completed && !hasLoggedWorkout else { return }
            hasLoggedWorkout = true
            Task {
                await handleWorkoutCompleted()
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

    // MARK: - Timer Control

    private func handlePlayPause() {
        // Ignore during countdown
        guard !countdown.isCountingDown else { return }

        if timerModel.isRunning {
            timerModel.pause()
            syncService?.sendTimerControl(.pause) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.pause) failed: \(error.localizedDescription)")
                }
            }
        } else if sessionManager.sessionState == .idle && !displayOnly {
            // First start: create workout session
            startTimerWithWorkoutSession()
            syncService?.sendTimerControl(.play) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.play) failed: \(error.localizedDescription)")
                }
            }
        } else {
            timerModel.start()
            syncService?.sendTimerControl(.play) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.play) failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleStop() {
        syncService?.sendTimerControl(.stop) { result in
            if case .failure(let error) = result {
                Logger.timerSync.warning("sendTimerControl(.stop) failed: \(error.localizedDescription)")
            }
        }
        stopAndCleanup()
    }

    /// Shared cleanup for both local and remote stop: ends the timer, tears down
    /// the HK workout session (removing the Live Activity), and dismisses the view.
    private func stopAndCleanup() {
        countdown.cancelCountdown()
        timerModel.reset()

        // End any active HK session and reset for reuse
        if sessionManager.sessionState != .idle {
            Task {
                let uuid = try? await sessionManager.endSession()
                sessionManager.resetToIdle()

                // Notify iPhone so it can correlate the HealthKit workout
                if displayOnly {
                    sendWorkoutSessionEnded(healthKitUUID: uuid)
                }
            }
        }

        dismiss()
    }

    /// Starts countdown if a scheduled start time was provided from iPhone.
    private func startCountdownIfNeeded() {
        guard let scheduledStartTime else { return }

        countdown.startCountdown(scheduledStartTime: scheduledStartTime) { [self] in
            startTimerWithWorkoutSession()
        }
    }

    /// Starts the timer and an HKWorkoutSession if one isn't already running.
    ///
    /// For iPhone-led workouts (Scenario C), the `WorkoutAppDelegate` has already
    /// started the session via `handle(_ workoutConfiguration:)`, so we skip
    /// session creation. For standalone Watch workouts (Scenarios B and D), we
    /// create the session here and start mirroring to iPhone.
    private func startTimerWithWorkoutSession() {
        timerModel.start()

        // Only start a new session if one isn't already running (from delegate)
        if sessionManager.sessionState == .idle {
            Task {
                do {
                    let config = HKWorkoutConfiguration()
                    config.activityType = .highIntensityIntervalTraining
                    config.locationType = .indoor
                    try await sessionManager.startSession(configuration: config)

                    // Mirror to iPhone so it can track this workout (Scenario D)
                    try await sessionManager.startMirroring()
                } catch {
                    Logger.workoutSession.error("Failed to start workout session: \(error.localizedDescription)")
                }
            }

            // Notify iPhone about the timer (best-effort, Watch workout proceeds regardless)
            let message = TimerStartedOnWatchMessage(
                timerKind: .amrap,
                totalDuration: totalDuration,
                exerciseName: exerciseName
            )
            WatchConnectivityService.shared.sendMessage(message, completion: nil)
        }
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
            if !timerModel.isRunning && !countdown.isCountingDown {
                timerModel.start()
            }
        case .pause:
            if timerModel.isRunning {
                timerModel.pause()
            }
        case .stop:
            stopAndCleanup()
        case .incrementRound:
            if timerModel.isRunning && !isCompleted {
                timerModel.incrementRoundsCompleted()
            }
        }
    }

    // MARK: - Mirrored Session Reconciliation

    /// Reconciles local timer state with the HKWorkoutSession state.
    ///
    /// When iPhone pauses/resumes via the mirrored session, the state change
    /// propagates to Watch's HKWorkoutSession delegate, updating
    /// `sessionManager.sessionState`. This method adjusts the local timer.
    ///
    /// Loop prevention: the WatchTimerLifecycleModifier calls
    /// `sessionManager.pause()`/`.resume()` when `timerModel.isRunning` changes,
    /// which triggers the delegate, which fires this `.onChange`. But if the timer
    /// is already in the matching state, the guard prevents any action.
    private func reconcileSessionState(_ newState: WorkoutSessionManager.SessionState) {
        switch newState {
        case .paused:
            if timerModel.isRunning {
                Logger.timerSync.info("Session state paused → pausing local timer (remote)")
                timerModel.pause()
            }
        case .running:
            if !timerModel.isRunning && !isCompleted && !countdown.isCountingDown {
                Logger.timerSync.info("Session state running → resuming local timer (remote)")
                timerModel.start()
            }
        case .idle, .ended:
            break
        }
    }

    // MARK: - Workout Session & Logging

    /// Handles workout completion for both standalone and iPhone-led scenarios.
    ///
    /// - Standalone (Scenario B): Ends HK session and logs to SwiftData.
    /// - iPhone-led (Scenario C): Ends HK session and sends UUID back to iPhone.
    ///   iPhone handles its own SwiftData logging.
    private func handleWorkoutCompleted() async {
        // End HKWorkoutSession (if running) regardless of displayOnly
        var healthKitUUID: UUID? = nil
        if sessionManager.sessionState == .running || sessionManager.sessionState == .paused {
            do {
                healthKitUUID = try await sessionManager.endSession()
            } catch {
                Logger.workoutSession.error("Failed to end workout session: \(error.localizedDescription)")
            }
        }

        if displayOnly {
            // iPhone-led: send UUID back to iPhone for correlation
            sendWorkoutSessionEnded(healthKitUUID: healthKitUUID)
        } else {
            // Standalone: log to SwiftData on Watch
            let log = WorkoutLog(
                exerciseName: exerciseName,
                timerKind: .amrap,
                durationSeconds: totalDuration,
                roundsCompleted: timerModel.roundsCompleted,
                healthKitWorkoutUUID: healthKitUUID
            )
            modelContext.insert(log)
            try? modelContext.save()
        }

        Logger.healthKit.info("Watch AMRAP workout completed, HealthKit UUID: \(healthKitUUID?.uuidString ?? "none"), displayOnly: \(displayOnly)")
    }

    /// Sends the workout session ended message to iPhone with the HealthKit UUID.
    private func sendWorkoutSessionEnded(healthKitUUID: UUID?) {
        let message = WorkoutSessionEndedMessage(healthKitWorkoutUUID: healthKitUUID)
        WatchConnectivityService.shared.sendMessage(message, completion: nil)
        Logger.healthKit.info("Sent workoutSessionEnded to iPhone, UUID: \(healthKitUUID?.uuidString ?? "none")")
    }
}

#Preview {
    NavigationStack {
        WatchAMRAPTimerView(totalDuration: 60)
    }
}
