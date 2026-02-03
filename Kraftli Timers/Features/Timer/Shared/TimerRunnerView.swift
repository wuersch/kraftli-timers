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
                .onReceive(timerSyncService.workoutSessionEndedReceived) { watchUUID in
                    updateLatestLogWithWatchUUID(watchUUID)
                }
        }
    }

    private var timerProvider: any TimerProvider {
        settings.smoothAnimationsEnabled ? DisplayLinkTimerProvider() : FoundationTimerProvider()
    }

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
                syncIntervalDuration: intervalDuration
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
                exerciseName: preset.exerciseInfo?.name ?? "Workout"
            )
        }
    }

    private var intervalDuration: TimeInterval {
        guard let targetReps = preset.targetReps, targetReps > 0 else {
            return preset.durationInterval
        }
        return preset.durationInterval / Double(targetReps)
    }

    /// Updates the most recent WorkoutLog with the Watch's HealthKit UUID.
    ///
    /// Called when Watch sends `workoutSessionEnded` after completing its HKWorkoutSession.
    /// This correlates our SwiftData record with the Watch's HealthKit workout entry.
    private func updateLatestLogWithWatchUUID(_ watchUUID: UUID?) {
        guard let watchUUID else { return }

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
        Logger.healthKit.info("Updated workout log with Watch HealthKit UUID: \(watchUUID)")
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

        return { completionData in
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
