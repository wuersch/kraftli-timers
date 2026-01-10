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

    var body: some View {
        NavigationStack {
            timerContent
                .navigationTitle("\(preset.exercise?.name ?? "Timer")\(UISeparator.dot)\(preset.kind.rawValue)")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var timerContent: some View {
        switch preset.kind {
        case .emom:
            EMOMTimerView(
                timerModel: EMOMTimerModel(
                    totalDuration: preset.durationInterval,
                    intervalDuration: intervalDuration
                ),
                onWorkoutCompleted: makeLoggingClosure()
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(
                    totalDuration: preset.durationInterval
                ),
                onWorkoutCompleted: makeLoggingClosure()
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
        let exerciseName = preset.exercise?.name ?? "Unknown"
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
    TimerRunnerView(
        preset: TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100,
            exercise: Exercise(name: "6-Count Burpees")
        )
    )
}

#Preview("AMRAP") {
    TimerRunnerView(
        preset: TimerPreset(
            kind: .amrap,
            durationInterval: 15 * 60,
            exercise: Exercise(name: "Pull-ups")
        )
    )
}
