//
//  TimerRunnerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 04.01.2026.
//

import SwiftUI
import SwiftData
import Combine
import HealthKit
import os

struct TimerRunnerView: View {
    let preset: TimerPreset

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(PhoneMessageCoordinator.self) private var messageCoordinator

    /// Service for syncing timer to Apple Watch.
    /// @State so the instance survives SwiftUI re-creating this struct —
    /// the coordinator forwards messages to the registered instance, and a
    /// fresh one per re-init would silently stop receiving them.
    @State private var timerSyncService: TimerSyncService

    /// Service for saving workouts to HealthKit.
    private let healthKitService: any HealthKitService

    /// Data for the workout summary screen, set when Watch sends completion message.
    @State private var summaryData: WorkoutSummaryData?

    /// Tracks completion data from the timer for summary display.
    @State private var lastCompletionData: WorkoutCompletionData?

    // MARK: - Swipe Gesture State

    /// Current vertical drag offset.
    @State private var dragOffset: CGFloat = 0

    /// Whether the drag handle is currently active (being dragged).
    @State private var isHandleActive = false

    /// Whether swipe is disabled (true during countdown).
    @State private var isSwipeDisabled = false

    /// Whether to show the swipe hint.
    @State private var showHint = true

    /// Whether to show confetti (triggered by timer completion, persists across summary transition).
    @State private var showConfetti = false

    /// Task to auto-hide confetti after 3 seconds.
    @State private var confettiHideTask: Task<Void, Never>?

    /// Cleanup action registered by timer view, called before dismissing.
    @State private var timerCleanup: (() -> Void)?

    /// Task that auto-transitions to the summary screen after a delay.
    @State private var summaryTransitionTask: Task<Void, Never>?

    /// Watch data that arrived before the transition delay completed.
    @State private var pendingWatchData: WorkoutSessionEndedMessage?

    init(
        preset: TimerPreset,
        timerSyncService: TimerSyncService = DefaultTimerSyncService(),
        healthKitService: any HealthKitService = DefaultHealthKitService()
    ) {
        self.preset = preset
        self._timerSyncService = State(initialValue: timerSyncService)
        self.healthKitService = healthKitService
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let data = summaryData {
                    // Show summary inline (replaces timer content)
                    WorkoutSummaryContent(data: data)
                        .transition(.opacity)
                } else {
                    timerContent
                        .transition(.opacity)
                }
            }
            .swipeToDismiss(
                dragOffset: $dragOffset,
                isHandleActive: $isHandleActive,
                onDismiss: handleDismiss,
                isDisabled: isSwipeDisabled
            )
            .overlay {
                // Hide handle during countdown
                if !isSwipeDisabled {
                    DragHandleView(isActive: isHandleActive, dragOffset: dragOffset)
                }
            }
            .overlay {
                // Show hint: always for summary, use timer's showHint otherwise
                SwipeHintOverlay(isVisible: shouldShowHint, fontSize: 15)
            }
            .overlay {
                // Confetti persists across timer→summary transition
                if showConfetti && settings.confettiEnabled {
                    ConfettiView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: showConfetti) { _, newValue in
                if newValue {
                    confettiHideTask?.cancel()
                    confettiHideTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        showConfetti = false
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timerSyncService.workoutSessionEndedReceived) { endedMessage in
                handleWorkoutSessionEnded(endedMessage)
            }
            .onAppear {
                // Register with the app-level coordinator so Watch messages
                // reach this timer's publishers.
                messageCoordinator.activeSyncService = timerSyncService as? DefaultTimerSyncService
            }
            .onDisappear {
                // Only clear if we're still the registered service — a newly
                // presented timer may already have taken over.
                if messageCoordinator.activeSyncService === timerSyncService as? DefaultTimerSyncService {
                    messageCoordinator.activeSyncService = nil
                }
            }
        }
    }

    /// Whether to show the swipe hint.
    /// Summary: always show. Timer: use timer's hint state.
    private var shouldShowHint: Bool {
        if summaryData != nil {
            return true
        }
        return showHint
    }

    /// Handles dismiss gesture - cleans up timer if running, then dismisses.
    private func handleDismiss() {
        summaryTransitionTask?.cancel()
        summaryTransitionTask = nil
        if summaryData == nil {
            // Timer is showing - call cleanup first
            timerCleanup?()
        } else {
            // Summary is showing - timer already completed, just tell Watch to dismiss
            timerSyncService.sendTimerControl(.stop) { result in
                if case .failure(let error) = result {
                    Logger.timerSync.warning("sendTimerControl(.stop) on summary dismiss failed: \(error.localizedDescription)")
                }
            }
        }
        dismiss()
    }

    private var navigationTitle: String {
        "\(preset.exerciseInfo?.name ?? "Timer")\(UISeparator.dot)\(preset.kind.rawValue)"
    }

    private var timerProvider: any TimerProvider {
        settings.smoothAnimationsEnabled ? DisplayLinkTimerProvider() : FoundationTimerProvider()
    }

    /// Pre-generated ID for correlating iPhone's WorkoutLog with Watch's HealthKit UUID.
    /// Sent to Watch via StartTimerMessage, echoed back in WorkoutSessionEndedMessage,
    /// and used as the WorkoutLog.id. @State so SwiftUI re-creating this struct keeps
    /// the ID stable — the Watch echoes the value from start time, and a regenerated
    /// ID would break the match.
    @State private var correlationID = UUID()

    @ViewBuilder
    private var timerContent: some View {
        let feedbackProvider: any FeedbackProvider = settings.audioEnabled
            ? settings.completionSoundStyle.makeFeedbackProvider()
            : SilentFeedback()

        switch preset.kind {
        case .emom:
            EMOMTimerView(
                timerModel: EMOMTimerModel(
                    totalDuration: preset.durationInterval,
                    intervalCount: preset.targetReps ?? 1,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                onWorkoutCompleted: makeLoggingClosure(),
                showRepsInCenter: settings.emomShowRepsInCenter,
                syncService: timerSyncService,
                healthKitService: healthKitService,
                exerciseName: preset.exerciseInfo?.name ?? "Workout",
                syncIntervalCount: preset.targetReps,
                correlationID: correlationID,
                autoStart: true,
                isSwipeDisabled: $isSwipeDisabled,
                showHint: $showHint,
                showConfetti: $showConfetti,
                onCleanupForDismiss: { cleanup in timerCleanup = cleanup },
                onDismissRequested: { dismiss() }
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(
                    totalDuration: preset.durationInterval,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                onWorkoutCompleted: makeLoggingClosure(),
                syncService: timerSyncService,
                healthKitService: healthKitService,
                exerciseName: preset.exerciseInfo?.name ?? "Workout",
                correlationID: correlationID,
                autoStart: true,
                isSwipeDisabled: $isSwipeDisabled,
                showHint: $showHint,
                showConfetti: $showConfetti,
                onCleanupForDismiss: { cleanup in timerCleanup = cleanup },
                onDismissRequested: { dismiss() }
            )
        }
    }

    /// Handles the workout session ended message from Watch.
    ///
    /// Merges health data into the summary. (The WorkoutLog HealthKit-UUID update
    /// happens in `PhoneMessageCoordinator`, which outlives this view.) If the
    /// summary is already showing, updates in-place with animation. If still in
    /// the delay period, stores data for pickup.
    private func handleWorkoutSessionEnded(_ endedMessage: WorkoutSessionEndedMessage) {
        if summaryData != nil {
            // Summary already showing — merge non-nil health fields in-place
            // (Watch sends nil fields when session ends on dismiss; guard against overwriting real data)
            withAnimation(.easeInOut(duration: 0.4)) {
                if let hr = endedMessage.averageHeartRate {
                    summaryData?.averageHeartRate = hr
                }
                if let maxHR = endedMessage.maxHeartRate {
                    summaryData?.maxHeartRate = maxHR
                }
                if let cal = endedMessage.activeCalories {
                    summaryData?.activeCalories = cal
                }
            }
        } else {
            // Still in delay period — store for transitionToSummary() to pick up
            pendingWatchData = endedMessage
        }
    }

    /// Transitions from the timer to the summary screen.
    ///
    /// Called after the post-completion delay. Creates the summary data
    /// from the completion data, merging in any Watch health metrics that
    /// arrived during the delay.
    private func transitionToSummary() {
        guard let completionData = lastCompletionData else { return }

        var data = WorkoutSummaryData(
            exerciseName: preset.exerciseInfo?.name ?? "Workout",
            timerKind: preset.kind,
            duration: completionData.durationSeconds,
            reps: completionData.repsCompleted,
            rounds: completionData.roundsCompleted,
            watchHandledWorkout: completionData.watchHandledWorkout
        )

        // Merge Watch data if it arrived during the delay
        if let watchData = pendingWatchData {
            data.averageHeartRate = watchData.averageHeartRate
            data.maxHeartRate = watchData.maxHeartRate
            data.activeCalories = watchData.activeCalories
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            summaryData = data
        }
    }

    /// Creates a closure that logs the completed workout to HealthKit and SwiftData.
    ///
    /// The flow depends on who handled the HealthKit workout:
    /// - **iPhone-only (Scenario A)**: Save to HealthKit on iPhone, then SwiftData with UUID.
    /// - **Watch handled (Scenario C/D)**: Skip iPhone HealthKit save (Watch already saved).
    ///   Save to SwiftData without UUID initially; Watch sends UUID via `workoutSessionEnded`.
    ///
    /// If HealthKit fails, the workout is still saved locally to SwiftData.
    private func makeLoggingClosure() -> (WorkoutCompletionData) -> Void {
        let exerciseName = preset.exerciseInfo?.name ?? "Unknown"
        let timerKind = preset.kind
        let context = modelContext
        let healthKit = healthKitService

        return { [self] completionData in
            // Store completion data for the workout summary
            self.lastCompletionData = completionData

            // Schedule auto-transition to summary after a short delay
            // (confetti plays during the delay, timer stays frozen at 0:00)
            self.summaryTransitionTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                self.transitionToSummary()
            }

            Task { @MainActor in
                // 1. Save to SwiftData first (always, regardless of HealthKit)
                let loggingService = DefaultWorkoutLoggingService(modelContext: context)
                let workoutLog = loggingService.logWorkout(
                    exerciseName: exerciseName,
                    timerKind: timerKind,
                    durationSeconds: completionData.durationSeconds,
                    repsCompleted: completionData.repsCompleted,
                    roundsCompleted: completionData.roundsCompleted
                )

                // Use the pre-generated correlation ID so Watch can match its
                // HealthKit UUID to this exact log (instead of "latest" heuristic).
                if let correlationID = completionData.correlationID {
                    workoutLog.id = correlationID
                    try? context.save()
                }

                // 2. Save to HealthKit (if iPhone is handling it)
                if completionData.watchHandledWorkout {
                    // Watch handled HKWorkoutSession — skip iPhone save to avoid duplicates.
                    // Watch will send its UUID via workoutSessionEnded message.
                    Logger.healthKit.info("Watch handled workout session, skipping iPhone HealthKit save")
                } else if healthKit.isAvailable {
                    // iPhone-only: save duration (no calories — those require Watch sensors)
                    let endDate = Date()
                    let startDate = endDate.addingTimeInterval(-completionData.durationSeconds)
                    do {
                        let healthKitUUID = try await healthKit.saveWorkout(
                            activityType: timerKind.healthKitActivityType,
                            start: startDate,
                            end: endDate,
                            metadata: [
                                HKMetadataKeyExternalUUID: workoutLog.id.uuidString,
                                "com.kraftli.timer.kind": timerKind.rawValue,
                                "com.kraftli.timer.exercise": exerciseName
                            ]
                        )

                        // Update SwiftData record with HealthKit UUID for correlation
                        workoutLog.healthKitWorkoutUUID = healthKitUUID
                        try? context.save()
                    } catch {
                        Logger.healthKit.error("Failed to save workout to HealthKit: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#Preview("EMOM") {
    ExerciseRepository.load()
    let exerciseId = ExerciseRepository.exercise(byName: "6-Count Burpees")?.id
    return TimerRunnerView(
        preset: TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100,
            exerciseId: exerciseId
        )
    )
    .environment(AppSettings())
    .environment(PhoneMessageCoordinator())
}

#Preview("AMRAP") {
    ExerciseRepository.load()
    let exerciseId = ExerciseRepository.exercise(byName: "Pull-ups")?.id
    return TimerRunnerView(
        preset: TimerPreset(
            kind: .amrap,
            durationInterval: 15 * 60,
            exerciseId: exerciseId
        )
    )
    .environment(AppSettings())
    .environment(PhoneMessageCoordinator())
}
