//
//  WatchPresetRowView.swift
//  Kraftli Timers Watch App
//
//  A row displaying a timer preset for the Watch preset list.
//

import SwiftUI

struct WatchPresetRowView: View {
    let preset: TimerPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preset.primaryText)
                .font(.headline)

            if !preset.secondaryText.isEmpty {
                Text(preset.secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    List {
        WatchPresetRowView(preset: TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100
        ))
        WatchPresetRowView(preset: TimerPreset(
            kind: .amrap,
            durationInterval: 5 * 60
        ))
    }
}
