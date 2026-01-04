//
//  TimerRunnerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 04.01.2026.
//

import SwiftUI

struct TimerRunnerView: View {
    let preset: TimerPreset

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
            EMOMTimerView(timerModel: EMOMTimerModel(
                totalDuration: preset.durationInterval,
                intervalDuration: intervalDuration
            ))
        case .amrap:
            AMRAPTimerView(timerModel: AMRAPTimerModel(
                totalDuration: preset.durationInterval
            ))
        }
    }

    private var intervalDuration: TimeInterval {
        guard let targetReps = preset.targetReps, targetReps > 0 else {
            return preset.durationInterval
        }
        return preset.durationInterval / Double(targetReps)
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
