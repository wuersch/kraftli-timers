//
//  WatchWorkoutCoordinator.swift
//  Kraftli Timers Watch App
//
//  Extracts shared workout lifecycle logic from WatchAMRAPTimerView and
//  WatchEMOMTimerView. Handles play/pause/stop, HK workout sessions,
//  countdown scheduling, remote control subscriptions, session state
//  reconciliation, and workout completion logging.
//
//  Timer-specific behavior (timer kind, completion data, remote control
//  handling for incrementRound) is provided via callbacks.
//

import SwiftUI
import SwiftData
import HealthKit
import Combine
import os

/// Configuration for a Watch workout, capturing the timer-specific details
/// that differ between AMRAP and EMOM.
struct WatchWorkoutConfig {
    let timerKind: TimerKind
    let totalDuration: TimeInterval
    let intervalDuration: TimeInterval?
    let exerciseName: String
    let displayOnly: Bool
    let scheduledStartTime: Date?
    let correlationID: UUID?

    /// Creates a `WorkoutLog` from the completed workout data.
    /// AMRAP uses `roundsCompleted`; EMOM uses `repsCompleted`.
    let makeWorkoutLog: (_ healthKitUUID: UUID?) -> WorkoutLog
}

/// Coordinates workout lifecycle operations shared between Watch timer views.
///
/// ## What This Does
/// Manages the lifecycle of a Watch workout: starting/stopping the HK session,
/// handling play/pause/stop commands (local and remote), countdown scheduling,
/// session state reconciliation (for iPhone-initiated pause/resume via mirrored
/// sessions), and workout completion (logging + sending UUID to iPhone).
///
/// ## How to Use
/// Each timer view creates a `WatchWorkoutCoordinator` and delegates lifecycle
/// calls to it. The coordinator operates on a `WorkoutTimer` (the timer model)
/// and a `WatchCountdownCoordinator` (the countdown state), both owned by the view.
///
/// ## SwiftUI Integration
/// This is a plain struct with methods, not an `@Observable` class. The timer
/// views own the state (`timerModel`, `countdown`, `cancellables`) and pass
/// references to the coordinator's methods. This avoids duplicating state
/// ownership and keeps SwiftUI's observation system working correctly.
struct WatchWorkoutCoordinator {
    let config: WatchWorkoutConfig
    let syncService: WatchTimerSyncService
    let sessionManager: WorkoutSessionManager

    // MARK: - Play / Pause / Stop

    /// Handles play/pause toggle. Call this from the view's play/pause button.
    ///
    /// - Parameters:
    ///   - timer: The workout timer model
    ///   - countdown: The countdown coordinator
    ///   - isCompleted: Whether the timer has finished
    ///   - startTimerWithWorkoutSession: Closure to call for first start (creates HK session)
    func handlePlayPause(
        timer: some WorkoutTimer,
        countdown: WatchCountdownCoordinator,
        isCompleted: Bool,
        startTimerWithWorkoutSession: () -> Void
    ) {
        guard !countdown.isCountingDown else { return }

        if timer.isRunning {
            timer.pause()
            syncService.sendTimerControl(.pause) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.pause) failed: \(error.localizedDescription)")
                }
            }
        } else if sessionManager.sessionState == .idle && !config.displayOnly {
            // First start: create workout session
            startTimerWithWorkoutSession()
            syncService.sendTimerControl(.play) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.play) failed: \(error.localizedDescription)")
                }
            }
        } else {
            timer.start()
            syncService.sendTimerControl(.play) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.play) failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Handles stop action. Sends stop to iPhone then cleans up locally.
    func handleStop(
        timer: some WorkoutTimer,
        countdown: WatchCountdownCoordinator,
        dismiss: DismissAction
    ) {
        syncService.sendTimerControl(.stop) { result in
            if case .failure(let error) = result {
                Logger.timerSync.warning("sendTimerControl(.stop) failed: \(error.localizedDescription)")
            }
        }
        stopAndCleanup(timer: timer, countdown: countdown, dismiss: dismiss)
    }

    /// Shared cleanup: ends the timer, tears down the HK session, dismisses.
    func stopAndCleanup(
        timer: some WorkoutTimer,
        countdown: WatchCountdownCoordinator,
        dismiss: DismissAction
    ) {
        countdown.cancelCountdown()
        timer.reset()

        if sessionManager.sessionState != .idle {
            // Capture metrics before ending session (they're cleared on end)
            let averageHeartRate = sessionManager.averageHeartRate
            let maxHeartRate = sessionManager.maxHeartRate
            let activeCalories = sessionManager.activeCalories

            Task {
                let uuid = await sessionManager.endSession()
                sessionManager.resetToIdle()

                if config.displayOnly {
                    sendWorkoutSessionEnded(
                        healthKitUUID: uuid,
                        averageHeartRate: averageHeartRate,
                        maxHeartRate: maxHeartRate,
                        activeCalories: activeCalories
                    )
                }
            }
        }

        dismiss()
    }

    // MARK: - Countdown & Session Start

    /// Starts the countdown if a scheduled start time was provided from iPhone.
    func startCountdownIfNeeded(
        countdown: WatchCountdownCoordinator,
        startTimerWithWorkoutSession: @escaping () -> Void
    ) {
        guard let scheduledStartTime = config.scheduledStartTime else { return }

        countdown.startCountdown(scheduledStartTime: scheduledStartTime) {
            startTimerWithWorkoutSession()
        }
    }

    /// Starts the timer and an HKWorkoutSession if one isn't already running.
    ///
    /// For iPhone-led workouts (Scenario C), the session was already started
    /// via `handle(_ workoutConfiguration:)`. For standalone (Scenarios B/D),
    /// we create the session and start mirroring to iPhone.
    func startTimerWithWorkoutSession(timer: some WorkoutTimer) {
        timer.start()

        Logger.workoutSession.info("startTimerWithWorkoutSession: sessionState=\(String(describing: self.sessionManager.sessionState))")
        if sessionManager.sessionState == .idle {
            Task {
                do {
                    let config = HKWorkoutConfiguration()
                    config.activityType = .highIntensityIntervalTraining
                    config.locationType = .indoor
                    try await sessionManager.startSession(configuration: config)
                    try await sessionManager.startMirroring()
                } catch {
                    Logger.workoutSession.error("Failed to start workout session: \(error.localizedDescription)")
                }
            }

            syncService.sendTimerStartedOnWatch(
                kind: self.config.timerKind,
                totalDuration: self.config.totalDuration,
                intervalDuration: self.config.intervalDuration,
                exerciseName: self.config.exerciseName,
                completion: nil
            )
        }
    }

    // MARK: - Remote Control

    /// Sets up the subscription for control messages from iPhone.
    func setupControlSubscription(
        cancellables: inout Set<AnyCancellable>,
        handleRemoteControl: @escaping (TimerControlAction) -> Void
    ) {
        syncService.timerControlReceived
            .receive(on: DispatchQueue.main)
            .sink { action in
                handleRemoteControl(action)
            }
            .store(in: &cancellables)
    }

    /// Default remote control handler. Call this from the view, adding any
    /// timer-specific handling (e.g., `.incrementRound` for AMRAP).
    func handleRemoteControl(
        _ action: TimerControlAction,
        timer: some WorkoutTimer,
        countdown: WatchCountdownCoordinator,
        isCompleted: Bool,
        dismiss: DismissAction
    ) {
        switch action {
        case .play:
            if !timer.isRunning && !countdown.isCountingDown {
                timer.start()
            }
        case .pause:
            if timer.isRunning {
                timer.pause()
            }
        case .stop:
            stopAndCleanup(timer: timer, countdown: countdown, dismiss: dismiss)
        case .incrementRound:
            break  // Handled by AMRAP view directly
        }
    }

    // MARK: - Session State Reconciliation

    /// Reconciles local timer state with the HKWorkoutSession state.
    ///
    /// When iPhone pauses/resumes via the mirrored session, the state change
    /// propagates to Watch's HKWorkoutSession, updating `sessionManager.sessionState`.
    func reconcileSessionState(
        _ newState: WorkoutSessionManager.SessionState,
        timer: some WorkoutTimer,
        isCompleted: Bool,
        isCountingDown: Bool
    ) {
        switch newState {
        case .paused:
            if timer.isRunning {
                Logger.timerSync.info("Session state paused → pausing local timer (remote)")
                timer.pause()
            }
        case .running:
            if !timer.isRunning && !isCompleted && !isCountingDown {
                Logger.timerSync.info("Session state running → resuming local timer (remote)")
                timer.start()
            }
        case .idle, .ended:
            break
        }
    }

    // MARK: - Workout Completion & Logging

    /// Handles workout completion: ends HK session and either logs locally
    /// (standalone) or sends UUID to iPhone (display-only/mirrored).
    func handleWorkoutCompleted(modelContext: ModelContext) async {
        // Capture metrics before ending session (they're cleared on end)
        let averageHeartRate = sessionManager.averageHeartRate
        let maxHeartRate = sessionManager.maxHeartRate
        let activeCalories = sessionManager.activeCalories

        var healthKitUUID: UUID? = nil
        if sessionManager.sessionState == .running || sessionManager.sessionState == .paused {
            healthKitUUID = await sessionManager.endSession()
        }

        if config.displayOnly {
            sendWorkoutSessionEnded(
                healthKitUUID: healthKitUUID,
                averageHeartRate: averageHeartRate,
                maxHeartRate: maxHeartRate,
                activeCalories: activeCalories
            )
        } else {
            let log = config.makeWorkoutLog(healthKitUUID)
            modelContext.insert(log)
            try? modelContext.save()
        }

        Logger.healthKit.info("Watch \(config.timerKind.rawValue) workout completed, HealthKit UUID: \(healthKitUUID?.uuidString ?? "none"), displayOnly: \(config.displayOnly), avgHR: \(averageHeartRate.map { String(format: "%.0f", $0) } ?? "none")")

        // Reset to idle so the next timer run can start a fresh HK session.
        // Without this, sessionState stays .ended and startSession() bails out.
        Logger.workoutSession.info("handleWorkoutCompleted: resetting to idle (was \(String(describing: self.sessionManager.sessionState)))")
        sessionManager.resetToIdle()
        Logger.workoutSession.info("handleWorkoutCompleted: sessionState is now \(String(describing: self.sessionManager.sessionState))")
    }

    // MARK: - Private

    private func sendWorkoutSessionEnded(
        healthKitUUID: UUID?,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        activeCalories: Double?
    ) {
        syncService.sendWorkoutSessionEnded(
            healthKitUUID: healthKitUUID,
            correlationID: config.correlationID,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            activeCalories: activeCalories,
            completion: nil
        )
    }
}
