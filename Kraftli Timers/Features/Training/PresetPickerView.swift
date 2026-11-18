//
//  PresetPickerView.swift
//  Kraftli Timers
//
//  Builds a session step from an existing preset (UC-0013 extension 3b).
//

import SwiftData
import SwiftUI

/// Lists the timer presets; tapping one hands back a step with a copy of its settings.
/// The step has no link to the preset: later changes to one don't reach the other.
struct PresetPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    let onPick: (SessionStep) -> Void

    var body: some View {
        NavigationStack {
            List(presets) { preset in
                Button {
                    onPick(PresetDraft(preset: preset).step())
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(preset.kind.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.primaryText).font(.headline)
                            if !preset.secondaryText.isEmpty {
                                Text(preset.secondaryText).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .overlay {
                if presets.isEmpty {
                    ContentUnavailableView(
                        "No Timers",
                        systemImage: "timer",
                        description: Text("Create timer presets on the Timers tab")
                    )
                }
            }
            .navigationTitle("Add from Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
    }
}

#Preview {
    PresetPickerView { _ in }
        .modelContainer(for: TimerPreset.self, inMemory: true)
}
