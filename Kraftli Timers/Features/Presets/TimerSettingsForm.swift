//
//  TimerSettingsForm.swift
//  Kraftli Timers
//
//  The form for one timer's settings: kind, exercise, duration and reps.
//

import SwiftUI

/// The controls for one timer's settings, bound to a `PresetDraft`.
///
/// Used by the preset editor and by the step editor of a session, which is why it
/// has no navigation bar or toolbar of its own: the host decides what Cancel and Save
/// mean. It applies the draft's rules as the athlete edits (clamping the reps, keeping
/// holds out of For Time).
struct TimerSettingsForm: View {
    @Binding var draft: PresetDraft

    @State private var showingExerciseSelection = false

    // MARK: - Subviews

    private var durationPicker: some View {
        Picker("Duration", selection: $draft.durationMinutes) {
            ForEach(1...60, id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    private var targetRepsPicker: some View {
        Picker("Total Reps", selection: $draft.targetReps) {
            ForEach(draft.repsRange, id: \.self) { reps in
                Text("\(reps)").tag(reps)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }

    private var exerciseButtonContent: some View {
        VStack(alignment: .leading) {
            HStack {
                if let exercise = draft.selectedExercise {
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

            if let exercise = draft.selectedExercise {
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

    /// The kind picker's selection. A segmented `Picker` can't disable a single segment,
    /// so a kind the draft doesn't offer (For Time with a hold) is refused here instead:
    /// a `Binding` built from closures lets the setter decide what reaches the state.
    private var offeredKind: Binding<TimerKind> {
        Binding(
            get: { draft.kind },
            set: { if draft.offers($0) { draft.kind = $0 } }
        )
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Timer Kind", selection: offeredKind) {
                    ForEach(TimerKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if let reason = draft.forTimeUnavailableReason {
                    Text(reason)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                switch draft.kind {
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
                    draft.selectedExercise.map { "Exercise: \($0.name)" }
                        ?? "Select exercise"
                )
                .accessibilityHint("Opens exercise selection")
            }

            switch draft.kind {
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
                        Text(draft.intervalDuration.intervalDescription())
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
        .onChange(of: draft.durationMinutes) { _, _ in
            draft.clampTargetReps()
        }
        .onChange(of: draft.kind) { _, _ in
            draft.clampTargetReps()
        }
        .onAppear {
            draft.selectDefaultExerciseIfNeeded()
        }
        .sheet(isPresented: $showingExerciseSelection) {
            ExerciseSelectionView(selectedExerciseId: $draft.exerciseId, kind: draft.kind)
        }
    }
}

#Preview {
    @Previewable @State var draft = PresetDraft()

    TimerSettingsForm(draft: $draft)
        .onAppear { ExerciseRepository.load() }
}
