//
//  WatchPresetEditorView.swift
//  Kraftli Timers Watch App
//
//  Preset editor optimized for watchOS with Digital Crown input.
//

import SwiftUI
import SwiftData

/// Editor for creating and modifying timer presets on watchOS.
///
/// ## Features
/// - Timer kind selection (EMOM/AMRAP) via segmented control
/// - Exercise selection via navigation drill-down
/// - Duration and reps input via Digital Crown
/// - Create new or edit existing presets
///
/// ## Data Flow
/// Changes are persisted to SwiftData and automatically sync via CloudKit.
struct WatchPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    let presetToEdit: TimerPreset?

    @State private var timerKind: TimerKind
    @State private var selectedExerciseId: UUID?
    @State private var durationMinutes: Double
    @State private var targetReps: Double

    // MARK: - Initialization

    init(presetToEdit: TimerPreset? = nil) {
        self.presetToEdit = presetToEdit

        if let preset = presetToEdit {
            _timerKind = State(initialValue: preset.kind)
            _selectedExerciseId = State(initialValue: preset.exerciseId)
            _durationMinutes = State(initialValue: preset.durationInterval / 60)
            _targetReps = State(initialValue: Double(preset.targetReps ?? 100))
        } else {
            _timerKind = State(initialValue: .emom)
            _selectedExerciseId = State(initialValue: nil)
            _durationMinutes = State(initialValue: 20)
            _targetReps = State(initialValue: 100)
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
    private var maxReps: Double {
        Double(TimerPreset.maximumReps(forDuration: durationMinutes * 60))
    }

    /// Calculated interval duration for display.
    private var intervalSeconds: TimeInterval {
        guard targetReps > 0 else { return 0 }
        return (durationMinutes * 60) / targetReps
    }

    private var isEditing: Bool {
        presetToEdit != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    timerKindSection
                    exerciseSection
                    durationSection

                    if timerKind == .emom {
                        repsSection
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle(isEditing ? "Edit Timer" : "New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savePreset()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .onAppear {
                // Select first exercise if none selected
                if selectedExerciseId == nil, let first = ExerciseRepository.all.first {
                    selectedExerciseId = first.id
                }
            }
            .onChange(of: durationMinutes) { _, _ in
                // Clamp reps if they exceed new max
                if targetReps > maxReps {
                    targetReps = maxReps
                }
            }
        }
    }

    // MARK: - Sections

    private var timerKindSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Timer Type")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(TimerKind.allCases, id: \.self) { kind in
                    Button {
                        timerKind = kind
                    } label: {
                        Text(kind.rawValue)
                            .font(.body.weight(timerKind == kind ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(timerKind == kind ? Color.green : Color.gray.opacity(0.2))
                            )
                            .foregroundStyle(timerKind == kind ? .black : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exercise")
                .font(.caption)
                .foregroundStyle(.secondary)

            NavigationLink {
                WatchExerciseListView(selectedExerciseId: $selectedExerciseId)
            } label: {
                HStack {
                    Text(selectedExercise?.name ?? "Select Exercise")
                        .font(.body)
                        .foregroundStyle(selectedExercise != nil ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var durationSection: some View {
        DigitalCrownStepperView(
            label: "Duration",
            value: $durationMinutes,
            unit: "min",
            range: 1...60
        )
    }

    private var repsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            DigitalCrownStepperView(
                label: "Total Reps",
                value: $targetReps,
                unit: "reps",
                range: 1...maxReps
            )

            Text(intervalSeconds.intervalDescription(compact: true))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Actions

    private func savePreset() {
        if let existingPreset = presetToEdit {
            // Update existing preset
            existingPreset.kindRawValue = timerKind.rawValue
            existingPreset.durationInterval = durationMinutes * 60
            existingPreset.targetReps = timerKind == .emom ? Int(targetReps) : nil
            existingPreset.exerciseId = selectedExerciseId
        } else {
            // Create new preset
            let preset = TimerPreset(
                kind: timerKind,
                durationInterval: durationMinutes * 60,
                targetReps: timerKind == .emom ? Int(targetReps) : nil,
                sortOrder: PresetMaintenance.nextSortOrder(after: presets),
                exerciseId: selectedExerciseId
            )
            modelContext.insert(preset)
        }
        dismiss()
    }
}

#Preview("New Preset") {
    WatchPresetEditorView()
        .modelContainer(for: TimerPreset.self, inMemory: true)
        .onAppear { ExerciseRepository.load() }
}

#Preview("Edit Preset") {
    let container = try! ModelContainer(
        for: TimerPreset.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    ExerciseRepository.load()

    // Find burpees exercise from repository
    let exerciseId = ExerciseRepository.exercise(byName: "6-Count Burpees")?.id

    let preset = TimerPreset(
        kind: .emom,
        durationInterval: 20 * 60,
        targetReps: 100,
        exerciseId: exerciseId
    )
    container.mainContext.insert(preset)

    return WatchPresetEditorView(presetToEdit: preset)
        .modelContainer(container)
}
