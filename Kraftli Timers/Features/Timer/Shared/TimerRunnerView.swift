//
//  TimerRunnerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 04.01.2026.
//

import SwiftUI
import SwiftData

struct TimerRunnerView: View {
    let preset: TimerPreset

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    /// Service for syncing timer to Apple Watch.
    private let timerSyncService: TimerSyncService

    init(preset: TimerPreset, timerSyncService: TimerSyncService = DefaultTimerSyncService()) {
        self.preset = preset
        self.timerSyncService = timerSyncService
    }

    var body: some View {
        NavigationStack {
            timerContent
                .navigationTitle("\(preset.exerciseInfo?.name ?? "Timer")\(UISeparator.dot)\(preset.kind.rawValue)")
                .navigationBarTitleDisplayMode(.inline)
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

    /// Creates a closure that logs the completed workout to SwiftData.
    private func makeLoggingClosure() -> (WorkoutCompletionData) -> Void {
        let exerciseName = preset.exerciseInfo?.name ?? "Unknown"
        let timerKind = preset.kind
        let context = modelContext

        return { completionData in
            // Ensure MainActor isolation for thread-safe ModelContext access
            Task { @MainActor in
                let loggingService = DefaultWorkoutLoggingService(modelContext: context)
                loggingService.logWorkout(
                    exerciseName: exerciseName,
                    timerKind: timerKind,
                    durationSeconds: completionData.durationSeconds,
                    repsCompleted: completionData.repsCompleted,
                    roundsCompleted: completionData.roundsCompleted
                )
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
