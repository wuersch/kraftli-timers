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

    @State private var timerKind: TimerKind
    @State private var selectedExerciseId: UUID?
    @State private var durationMinutes: Int
    @State private var targetReps: Int
    @State private var showingExerciseSelection = false

    init(presetToEdit: TimerPreset? = nil) {
        self.presetToEdit = presetToEdit

        // Initialize state from preset or use defaults
        if let preset = presetToEdit {
            _timerKind = State(initialValue: preset.kind)
            _selectedExerciseId = State(initialValue: preset.exerciseId)
            // For Time presets store no duration (0); offer the default if the kind changes.
            _durationMinutes = State(
                initialValue: preset.durationInterval > 0 ? Int(preset.durationInterval / 60) : 20
            )
            _targetReps = State(initialValue: preset.targetReps ?? TimerPreset.defaultForTimeReps)
        } else {
            _timerKind = State(initialValue: .emom)
            _selectedExerciseId = State(initialValue: nil)
            _durationMinutes = State(initialValue: 20)
            _targetReps = State(initialValue: TimerPreset.defaultForTimeReps)
        }
    }

    // MARK: - Computed Properties

    private var selectedExercise: ExerciseInfo? {
        guard let id = selectedExerciseId else {
            return ExerciseRepository.all.first
        }
        return ExerciseRepository.exercise(byId: id)
    }

    /// Maximum reps based on duration (uses shared constant for minimum interval).
    private var maxReps: Int {
        TimerPreset.maximumReps(forDuration: TimeInterval(durationMinutes * 60))
    }

    /// Calculated interval duration for display.
    private var intervalDuration: TimeInterval {
        guard targetReps > 0 else { return 0 }
        return TimeInterval(durationMinutes * 60) / Double(targetReps)
    }

    private var intervalDescription: String {
        intervalDuration.intervalDescription()
    }

    // MARK: - Subviews

    private var durationPicker: some View {
        Picker("Duration", selection: $durationMinutes) {
            ForEach(1...60, id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    /// EMOM caps the reps by the duration; For Time allows 1–999.
    private var repsRange: ClosedRange<Int> {
        timerKind == .forTime ? TimerPreset.forTimeRepsRange : 1...maxReps
    }

    private var targetRepsPicker: some View {
        Picker("Total Reps", selection: $targetReps) {
            ForEach(repsRange, id: \.self) { reps in
                Text("\(reps)").tag(reps)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    private var exerciseButtonContent: some View {
        VStack(alignment: .leading) {
            HStack {
                if let exercise = selectedExercise {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("Select Exercise")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if let exercise = selectedExercise {
                Divider()

                HStack(spacing: 8) {
                    MuscleGroupTag(muscleGroup: exercise.muscleGroup, size: .compact)
                    if let difficulty = exercise.difficulty {
                        DifficultyIndicator(
                            difficulty: difficulty,
                            style: .pill
                        )
                    }
                }
            }
        }
        .contentShape(Rectangle())
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

                    switch timerKind {
                    case .amrap:
                        Text(
                            "A time-capped workout where you perform as many reps or rounds as possible."
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    case .emom:
                        Text(
                            "A time-based workout where you perform a fixed number of reps at regular intervals across the total duration."
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    case .forTime:
                        Text(
                            "A fixed number of reps done as fast as possible. Tap when done to stop the clock."
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                }

                Section {
                    Button(action: { showingExerciseSelection = true }) {
                        exerciseButtonContent
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        selectedExercise.map { "Exercise: \($0.name)" }
                            ?? "Select exercise"
                    )
                    .accessibilityHint("Opens exercise selection")
                }

                switch timerKind {
                case .amrap:
                    Section {

                        Text("Duration")
                            .font(.body)
                            .foregroundStyle(.primary)
                        durationPicker

                    }
                case .emom:
                    Section {
                        // Two-row layout to keep system separators while visually grouping label and controls
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Duration and Total Reps")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(intervalDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                        }

                        HStack {
                            durationPicker
                            targetRepsPicker
                        }
                    }
                case .forTime:
                    Section {
                        Text("Total Reps")
                            .font(.body)
                            .foregroundStyle(.primary)
                        targetRepsPicker
                    }
                }
            }
            .onChange(of: durationMinutes) { _, _ in
                clampTargetReps()
            }
            .onChange(of: timerKind) { _, _ in
                // Switching from For Time (up to 999) to EMOM may exceed the duration's cap.
                clampTargetReps()
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
                    .accessibilityLabel(
                        presetToEdit == nil ? "Save timer" : "Save changes"
                    )
                }
            }
            .onAppear {
                // Set default exercise if none selected
                if selectedExerciseId == nil, let first = ExerciseRepository.all.first {
                    selectedExerciseId = first.id
                }
            }
            .sheet(isPresented: $showingExerciseSelection) {
                ExerciseSelectionView(selectedExerciseId: $selectedExerciseId)
            }
        }
    }

    // MARK: - Actions

    /// Keeps the reps within the current kind's range.
    private func clampTargetReps() {
        targetReps = min(max(targetReps, repsRange.lowerBound), repsRange.upperBound)
    }

    private func savePreset() {
        // For Time has no duration; AMRAP has no reps.
        let duration: TimeInterval = timerKind.hasFixedDuration ? TimeInterval(durationMinutes * 60) : 0
        let reps: Int? = timerKind == .amrap ? nil : targetReps
        if let existingPreset = presetToEdit {
            // Update existing preset
            existingPreset.kindRawValue = timerKind.rawValue
            existingPreset.durationInterval = duration
            existingPreset.targetReps = reps
            existingPreset.exerciseId = selectedExerciseId
        } else {
            // Create new preset at end of list
            let preset = TimerPreset(
                kind: timerKind,
                durationInterval: duration,
                targetReps: reps,
                sortOrder: PresetMaintenance.nextSortOrder(after: presets),
                exerciseId: selectedExerciseId
            )
            modelContext.insert(preset)
        }
        dismiss()
    }
}

#Preview {
    TimerPresetEditorView()
        .modelContainer(for: TimerPreset.self, inMemory: true)
        .onAppear { ExerciseRepository.load() }
}
