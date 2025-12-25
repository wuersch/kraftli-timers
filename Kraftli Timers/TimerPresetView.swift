//
//  TimerPresetsView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 24.12.2025.
//

import SwiftUI

struct TimerPresetView: View {
    @State private var timerPresets = TimerPreset.defaults
    @State private var selectedPreset: TimerPreset?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(timerPresets) { preset in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.primaryText)
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text(preset.secondaryText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            Button(action: {
                                selectedPreset = preset
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                } header: {
                    Spacer()
                }
            }
            .navigationTitle("Timers")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(item: $selectedPreset) { preset in
            NavigationStack {
                switch preset.kind {
                case .emom:
                    if let intervalDuration = preset.intervalDuration {
                        let totalSeconds = TimeInterval(preset.duration.components.seconds)
                        let intervalSeconds = TimeInterval(intervalDuration.components.seconds)

                        EMOMTimerView(timerModel: EMOMTimerModel(
                            totalDuration: totalSeconds,
                            intervalDuration: intervalSeconds
                        ))
                        .navigationTitle("\(preset.exercise.name) ⸱ \(preset.kind.rawValue)")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                case .amrap:
                    let totalSeconds = TimeInterval(preset.duration.components.seconds)
                    AMRAPTimerView(timerModel: AMRAPTimerModel(totalDuration: totalSeconds))
                        .navigationTitle("\(preset.exercise.name) ⸱ \(preset.kind.rawValue)")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

#Preview {
    TimerPresetView()
}
