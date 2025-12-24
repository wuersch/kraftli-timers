//
//  TimerPresetsView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 24.12.2025.
//

import SwiftUI

struct TimerPresetView: View {
    @State private var timerPresets = TimerPreset.defaults

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

                            Button(action: {}) {
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
    }
}

#Preview {
    TimerPresetView()
}
