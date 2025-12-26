//
//  PresetEditorView.swift
//  Kraftli Timers
//
//  Created by Claude on 26.12.2025.
//

import SwiftUI

struct PresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let store: PresetStore
    let presetToEdit: TimerPreset?

    @State private var timerKind: TimerKind
    @State private var exercise: Exercise
    @State private var durationMinutes: Int
    @State private var targetReps: Int

    init(store: PresetStore, presetToEdit: TimerPreset? = nil) {
        self.store = store
        self.presetToEdit = presetToEdit

        // Initialize state from preset or use defaults
        if let preset = presetToEdit {
            _timerKind = State(initialValue: preset.kind)
            _exercise = State(initialValue: preset.exercise)
            _durationMinutes = State(initialValue: Int(preset.duration.components.seconds / 60))
            _targetReps = State(initialValue: preset.targetReps ?? 100)
        } else {
            _timerKind = State(initialValue: .emom)
            _exercise = State(initialValue: Exercise(name: "Pull-ups"))
            _durationMinutes = State(initialValue: 20)
            _targetReps = State(initialValue: 100)
        }
    }

    // Minimum interval duration: 3 seconds
    private var maxReps: Int {
        let totalSeconds = durationMinutes * 60
        return totalSeconds / 3
    }

    private var intervalDuration: Int {
        guard targetReps > 0 else { return 0 }
        let totalSeconds = durationMinutes * 60
        return totalSeconds / targetReps
    }

    private var intervalDescription: String {
        let seconds = intervalDuration
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) min per interval"
            } else {
                return "\(minutes) min \(remainingSeconds) sec per interval"
            }
        } else {
            return "\(seconds) sec per interval"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Timer Kind", selection: $timerKind) {
                        ForEach(TimerKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Exercise", selection: $exercise) {
                        ForEach(Exercise.availableExercises, id: \.self) { exercise in
                            Text(exercise.name).tag(exercise)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(1...60, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: durationMinutes) { _, _ in
                        // Ensure targetReps doesn't exceed maxReps when duration changes
                        if targetReps > maxReps {
                            targetReps = maxReps
                        }
                    }
                }

                if timerKind == .emom {
                    Section {
                        Picker("Target Reps", selection: $targetReps) {
                            ForEach(1...maxReps, id: \.self) { reps in
                                Text("\(reps)").tag(reps)
                            }
                        }
                        .pickerStyle(.menu)
                    } footer: {
                        Text(intervalDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(presetToEdit == nil ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        savePreset()
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    private func savePreset() {
        if let existingPreset = presetToEdit {
            // Update existing preset
            let updatedPreset = TimerPreset(
                id: existingPreset.id,
                kind: timerKind,
                duration: .seconds(Int64(durationMinutes * 60)),
                targetReps: timerKind == .emom ? targetReps : nil,
                exercise: exercise
            )
            store.updatePreset(updatedPreset)
        } else {
            // Create new preset
            let preset = TimerPreset(
                id: UUID(),
                kind: timerKind,
                duration: .seconds(Int64(durationMinutes * 60)),
                targetReps: timerKind == .emom ? targetReps : nil,
                exercise: exercise
            )
            store.addPreset(preset)
        }
        dismiss()
    }
}

#Preview {
    PresetEditorView(store: PresetStore())
}
