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
/// - Timer kind selection (EMOM/AMRAP/For Time) via buttons
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
    // The Digital Crown drives `Double` values, so duration and reps stay `Double`
    // state here and enter the shared `PresetDraft` as whole numbers (what is displayed).
    @State private var durationMinutes: Double
    @State private var targetReps: Double

    // MARK: - Initialization

    init(presetToEdit: TimerPreset? = nil) {
        self.presetToEdit = presetToEdit

        let draft = presetToEdit.map { PresetDraft(preset: $0) } ?? PresetDraft()
        _timerKind = State(initialValue: draft.kind)
        _selectedExerciseId = State(initialValue: draft.exerciseId)
        _durationMinutes = State(initialValue: Double(draft.durationMinutes))
        _targetReps = State(initialValue: Double(draft.targetReps))
    }

    // MARK: - Computed Properties

    /// The edited values with the shared rules for ranges, clamping and saving.
    private var draft: PresetDraft {
        PresetDraft(
            kind: timerKind,
            exerciseId: selectedExerciseId,
            durationMinutes: Int(durationMinutes),
            targetReps: Int(targetReps)
        )
    }

    /// EMOM caps the reps by the duration; For Time allows 1–999.
    private var repsRange: ClosedRange<Double> {
        let range = draft.repsRange
        return Double(range.lowerBound)...Double(range.upperBound)
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

                    if timerKind.hasFixedDuration {
                        durationSection
                    }
                    if timerKind != .amrap {
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
                var draft = draft
                draft.selectDefaultExerciseIfNeeded()
                selectedExerciseId = draft.exerciseId
            }
            .onChange(of: durationMinutes) { _, _ in
                clampTargetReps()
            }
            .onChange(of: timerKind) { _, _ in
                // Switching from For Time (up to 999) to EMOM may exceed the duration's cap.
                clampTargetReps()
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(timerKind == kind ? Color.green : Color.gray.opacity(0.2))
                            )
                            .foregroundStyle(timerKind == kind ? .black : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!draft.offers(kind))
                    .opacity(draft.offers(kind) ? 1 : 0.4)
                }
            }

            if let reason = draft.forTimeUnavailableReason {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exercise")
                .font(.caption)
                .foregroundStyle(.secondary)

            NavigationLink {
                WatchExerciseListView(selectedExerciseId: $selectedExerciseId, kind: timerKind)
            } label: {
                HStack {
                    Text(draft.selectedExercise?.name ?? "Select Exercise")
                        .font(.body)
                        .foregroundStyle(draft.selectedExercise != nil ? .primary : .secondary)
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
                range: repsRange
            )

            if timerKind == .emom {
                Text(draft.intervalDuration.intervalDescription(compact: true))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Actions

    /// Keeps the reps within the current kind's range.
    private func clampTargetReps() {
        targetReps = min(max(targetReps, repsRange.lowerBound), repsRange.upperBound)
    }

    private func savePreset() {
        draft.save(editing: presetToEdit, in: modelContext, after: presets)
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
