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

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    /// Service for syncing timer to Apple Watch.
    private let timerSyncService: TimerSyncService

    /// Service for saving workouts to HealthKit.
    private let healthKitService: any HealthKitService

    /// Data for the workout summary screen, set when Watch sends completion message.
    @State private var summaryData: WorkoutSummaryData?

    /// Tracks completion data from the timer for summary display.
    @State private var lastCompletionData: WorkoutCompletionData?

    init(
        preset: TimerPreset,
        timerSyncService: TimerSyncService = DefaultTimerSyncService(),
        healthKitService: any HealthKitService = DefaultHealthKitService()
    ) {
        self.preset = preset
        self.timerSyncService = timerSyncService
        self.healthKitService = healthKitService
    }

    var body: some View {
        NavigationStack {
            timerContent
                .navigationTitle("\(preset.exerciseInfo?.name ?? "Timer")\(UISeparator.dot)\(preset.kind.rawValue)")
                .navigationBarTitleDisplayMode(.inline)
                .onReceive(timerSyncService.workoutSessionEndedReceived) { endedMessage in
                    handleWorkoutSessionEnded(endedMessage)
                }
                .fullScreenCover(item: $summaryData) { data in
                    WorkoutSummaryView(
                        data: data,
                        confettiEnabled: settings.confettiEnabled
                    )
                }
        }
    }

    private var timerProvider: any TimerProvider {
        settings.smoothAnimationsEnabled ? DisplayLinkTimerProvider() : FoundationTimerProvider()
    }

    /// Pre-generated ID for correlating iPhone's WorkoutLog with Watch's HealthKit UUID.
    /// Generated once per TimerRunnerView instance, sent to Watch via StartTimerMessage,
    /// echoed back in WorkoutSessionEndedMessage, and used as the WorkoutLog.id.
    private let correlationID = UUID()

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
                    intervalDuration: intervalDuration,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                onWorkoutCompleted: makeLoggingClosure(),
                confettiEnabled: settings.confettiEnabled,
                showRepsInCenter: settings.emomShowRepsInCenter,
                syncService: timerSyncService,
                healthKitService: healthKitService,
                exerciseName: preset.exerciseInfo?.name ?? "Workout",
                syncIntervalDuration: intervalDuration,
                correlationID: correlationID
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(
                    totalDuration: preset.durationInterval,
                    timerProvider: timerProvider,
                    feedbackProvider: feedbackProvider
                ),
                onWorkoutCompleted: makeLoggingClosure(),
                confettiEnabled: settings.confettiEnabled,
                syncService: timerSyncService,
                healthKitService: healthKitService,
                exerciseName: preset.exerciseInfo?.name ?? "Workout",
                correlationID: correlationID
            )
        }
    }

    private var intervalDuration: TimeInterval {
        guard let targetReps = preset.targetReps, targetReps > 0 else {
            return preset.durationInterval
        }
        return preset.durationInterval / Double(targetReps)
    }

    /// Handles the workout session ended message from Watch.
    ///
    /// Updates the WorkoutLog with the HealthKit UUID, then shows the summary
    /// screen if health data is available and the setting is enabled.
    private func handleWorkoutSessionEnded(_ endedMessage: WorkoutSessionEndedMessage) {
        // First, update the log with the HealthKit UUID
        updateLogWithWatchUUID(endedMessage)

        // Then, check if we should show the summary
        let data = WorkoutSummaryData(
            exerciseName: preset.exerciseInfo?.name ?? "Workout",
            timerKind: preset.kind,
            duration: lastCompletionData?.durationSeconds ?? preset.durationInterval,
            reps: lastCompletionData?.repsCompleted ?? preset.targetReps,
            rounds: lastCompletionData?.roundsCompleted,
            averageHeartRate: endedMessage.averageHeartRate,
            maxHeartRate: endedMessage.maxHeartRate,
            activeCalories: endedMessage.activeCalories
        )

        if data.hasHealthData && settings.workoutSummaryEnabled {
            summaryData = data
        }
    }

    /// Updates a WorkoutLog with the Watch's HealthKit UUID.
    ///
    /// Uses the correlation ID for exact matching when available; falls back to the most
    /// recent log without a UUID if the correlation ID is missing (backwards compatibility).
    private func updateLogWithWatchUUID(_ endedMessage: WorkoutSessionEndedMessage) {
        guard let watchUUID = endedMessage.healthKitWorkoutUUID else { return }

        if let correlationID = endedMessage.correlationID {
            // Exact match by WorkoutLog ID
            let descriptor = FetchDescriptor<WorkoutLog>(
                predicate: #Predicate { $0.id == correlationID }
            )
            guard let log = try? modelContext.fetch(descriptor).first,
                  log.healthKitWorkoutUUID == nil else {
                return
            }
            log.healthKitWorkoutUUID = watchUUID
            try? modelContext.save()
            Logger.healthKit.info("Updated workout log \(correlationID) with Watch HealthKit UUID: \(watchUUID)")
        } else {
            // Fallback: match most recent log without a UUID
            let descriptor = FetchDescriptor<WorkoutLog>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            guard let logs = try? modelContext.fetch(descriptor),
                  let latestLog = logs.first,
                  latestLog.healthKitWorkoutUUID == nil else {
                return
            }
            latestLog.healthKitWorkoutUUID = watchUUID
            try? modelContext.save()
            Logger.healthKit.info("Updated latest workout log with Watch HealthKit UUID: \(watchUUID) (no correlation ID)")
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
}
