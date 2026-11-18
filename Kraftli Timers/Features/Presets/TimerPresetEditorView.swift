//
//  TimerPresetEditorView.swift
//  Kraftli Timers
//
//  Created by Claude on 26.12.2025.
//

import SwiftData
import SwiftUI

struct TimerPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var presets: [TimerPreset]

    let presetToEdit: TimerPreset?

    /// The values being edited. Nothing reaches the stored preset until Save.
    @State private var draft: PresetDraft

    init(presetToEdit: TimerPreset? = nil) {
        self.presetToEdit = presetToEdit
        _draft = State(initialValue: presetToEdit.map(PresetDraft.init(preset:)) ?? PresetDraft())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            TimerSettingsForm(draft: $draft)
                .navigationTitle(presetToEdit == nil ? "New Timer" : "Edit Timer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Cancel")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            savePreset()
                        }) {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel(
                            presetToEdit == nil ? "Save timer" : "Save changes"
                        )
                    }
                }
        }
    }

    // MARK: - Actions

    private func savePreset() {
        draft.save(editing: presetToEdit, in: modelContext, after: presets)
        dismiss()
    }
}

#Preview {
    TimerPresetEditorView()
        .modelContainer(for: TimerPreset.self, inMemory: true)
        .onAppear { ExerciseRepository.load() }
}
