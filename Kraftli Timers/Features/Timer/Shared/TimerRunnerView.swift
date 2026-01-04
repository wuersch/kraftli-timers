//
//  TimerRunnerView.swift
//  Kraftli Timers
//

import SwiftUI

struct TimerRunnerView: View {
    let preset: TimerPreset

    var body: some View {
        NavigationStack {
            timerContent
                .navigationTitle("\(preset.exercise?.name ?? "Timer") · \(preset.kind.rawValue)")
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
