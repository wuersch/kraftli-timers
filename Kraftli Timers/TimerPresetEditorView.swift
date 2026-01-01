//
//  TimerPresetEditorView.swift
//  Kraftli Timers
//
//  Created by Claude on 26.12.2025.
//

import SwiftUI
import SwiftData

struct TimerPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let presetToEdit: TimerPreset?

    @State private var timerKind: TimerKind
    @State private var selectedExerciseId: UUID?
    @State private var durationMinutes: Int
    @State private var targetReps: Int

    init(presetToEdit: TimerPreset? = nil) {
        self.presetToEdit = presetToEdit

        // Initialize state from preset or use defaults
        if let preset = presetToEdit {
            _timerKind = State(initialValue: preset.kind)
            _selectedExerciseId = State(initialValue: preset.exercise?.id)
            _durationMinutes = State(initialValue: Int(preset.durationInterval / 60))
            _targetReps = State(initialValue: preset.targetReps ?? 100)
        } else {
            _timerKind = State(initialValue: .emom)
            _selectedExerciseId = State(initialValue: nil)
            _durationMinutes = State(initialValue: 20)
            _targetReps = State(initialValue: 100)
        }
    }

    // MARK: - Computed Properties

    private var selectedExercise: Exercise? {
        guard let id = selectedExerciseId else {
            return exercises.first
        }
        return exercises.first { $0.id == id }
    }

    // Minimum interval duration: 3 seconds
    private var maxReps: Int {
        let totalSeconds = durationMinutes * 60
        return totalSeconds / 3
    }

    private var intervalDuration: Double {
        guard targetReps > 0 else { return 0 }
        let totalSeconds = durationMinutes * 60
        return Double(totalSeconds) / Double(targetReps)
    }

    private var intervalDescription: String {
        let seconds = intervalDuration
        if seconds >= 60 {
            let minutes = Int(seconds / 60)
            let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60)
            if remainingSeconds == 0 {
                return "\(minutes) min per interval"
            } else {
                // Show decimal only if not a whole number
                let formatted = remainingSeconds.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", remainingSeconds)
                    : String(format: "%.1f", remainingSeconds)
                return "\(minutes) min \(formatted) sec per interval"
            }
        } else {
            // Show decimal only if not a whole number
            let formatted = seconds.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", seconds)
                : String(format: "%.1f", seconds)
            return "\(formatted) sec per interval"
        }
    }

    // MARK: - Body

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
                    Picker("Exercise", selection: $selectedExerciseId) {
                        ForEach(exercises) { exercise in
                            Text(exercise.name).tag(exercise.id as UUID?)
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Reps")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Picker("Target Reps", selection: $targetReps) {
                                ForEach(1...maxReps, id: \.self) { reps in
                                    Text("\(reps)").tag(reps)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))
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
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        savePreset()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(presetToEdit == nil ? "Save timer" : "Save changes")
                }
            }
            .onAppear {
                // Set default exercise if none selected
                if selectedExerciseId == nil, let first = exercises.first {
                    selectedExerciseId = first.id
                }
            }
        }
    }

    // MARK: - Actions

    private func savePreset() {
        if let existingPreset = presetToEdit {
            // Update existing preset
            existingPreset.kindRawValue = timerKind.rawValue
            existingPreset.durationInterval = TimeInterval(durationMinutes * 60)
            existingPreset.targetReps = timerKind == .emom ? targetReps : nil
            existingPreset.exercise = selectedExercise
        } else {
            // Create new preset
            let maxSortOrder = (exercises.isEmpty ? -1 : exercises.count)
            let preset = TimerPreset(
                kind: timerKind,
                durationInterval: TimeInterval(durationMinutes * 60),
                targetReps: timerKind == .emom ? targetReps : nil,
                sortOrder: maxSortOrder,
                exercise: selectedExercise
            )
            modelContext.insert(preset)
        }
        dismiss()
    }
}

#Preview {
    TimerPresetEditorView()
        .modelContainer(for: [TimerPreset.self, Exercise.self], inMemory: true)
}
