//
//  WatchPresetListView.swift
//  Kraftli Timers Watch App
//
//  Displays synced timer presets from CloudKit.
//  Tap a preset to launch the appropriate timer.
//

import SwiftUI
import SwiftData
import os

// MARK: - Presentation Models

/// Identifies which editor sheet to present.
enum ActiveEditor: Identifiable {
    case add
    case edit(TimerPreset)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let preset): return preset.id.uuidString
        }
    }
}

/// The workout to present: its configuration is captured at tap time (or taken from the
/// iPhone's start request), ensuring the data is available when the cover presents.
/// This avoids SwiftUI state timing issues with `fullScreenCover(isPresented:)`.
///
/// All kinds run through the timer session (ADR-006), started on either device.
struct TimerPresentation: Identifiable, Equatable {
    let config: TimerConfig
    var workoutID = UUID()
    var startedOnPhone = false

    // The workout ID is the identity: a new start for the same preset must
    // re-create the timer view, not reuse the already-started one.
    var id: UUID { workoutID }
}

// MARK: - WatchPresetListView

struct WatchPresetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchWorkoutStarter.self) private var workoutStarter
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    /// The currently presented timer, if any. Using item-based presentation
    /// guarantees data is captured before the cover appears.
    @State private var activeTimer: TimerPresentation?

    /// The currently presented editor sheet, if any.
    @State private var activeEditor: ActiveEditor?

    var body: some View {
        Group {
            if presets.isEmpty {
                emptyStateView
            } else {
                presetListView
            }
        }
        .navigationTitle("Timers")
        .onAppear {
            // Consume a request that arrived before the view existed (cold launch).
            if let request = workoutStarter.requestedWorkout {
                presentRequestedWorkout(request)
            }
        }
        .onChange(of: workoutStarter.requestedWorkout) { _, request in
            guard let request else { return }
            presentRequestedWorkout(request)
        }
        .fullScreenCover(item: $activeTimer) { timer in
            timerView(for: timer)
        }
        .sheet(item: $activeEditor) { editor in
            switch editor {
            case .add:
                WatchPresetEditorView()
            case .edit(let preset):
                WatchPresetEditorView(presetToEdit: preset)
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("No presets")
                        .font(.headline)
                    Text("Create one to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                addButton
            }
            .padding()
        }
    }

    private var presetListView: some View {
        List {
            ForEach(presets) { preset in
                Button {
                    launchTimer(for: preset)
                } label: {
                    WatchPresetRowView(preset: preset)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deletePreset(preset)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        activeEditor = .edit(preset)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }

            addButton
                .listRowBackground(Color.clear)
        }
    }

    private var addButton: some View {
        Button {
            activeEditor = .add
        } label: {
            Image(systemName: "plus")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.mini)
        .tint(.gray)
        .scaleEffect(1.2)
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    // MARK: - Actions

    /// The timer view for the workout's kind.
    @ViewBuilder
    private func timerView(for timer: TimerPresentation) -> some View {
        let config = timer.config
        switch config.kind {
        case .emom:
            WatchEMOMTimerView(
                totalDuration: config.totalDuration ?? 0,
                intervalCount: config.intervalCount ?? 1,
                exerciseName: config.exerciseName,
                workoutID: timer.workoutID,
                startedOnPhone: timer.startedOnPhone
            )
        case .amrap:
            WatchAMRAPTimerView(
                totalDuration: config.totalDuration ?? 0,
                exerciseName: config.exerciseName,
                workoutID: timer.workoutID,
                startedOnPhone: timer.startedOnPhone
            )
        case .forTime:
            WatchForTimeTimerView(
                targetReps: config.targetReps ?? TimerPreset.defaultForTimeReps,
                exerciseName: config.exerciseName,
                workoutID: timer.workoutID,
                startedOnPhone: timer.startedOnPhone
            )
        }
    }

    private func launchTimer(for preset: TimerPreset) {
        let kind = preset.kind
        activeTimer = TimerPresentation(config: TimerConfig(
            kind: kind,
            totalDuration: kind.hasFixedDuration ? preset.durationInterval : nil,
            intervalCount: kind == .emom ? preset.targetReps ?? 1 : nil,
            exerciseName: preset.exerciseInfo?.name ?? "\(kind.rawValue) Workout",
            targetReps: kind == .forTime ? preset.targetReps ?? TimerPreset.defaultForTimeReps : nil
        ))
    }

    private func deletePreset(_ preset: TimerPreset) {
        modelContext.delete(preset)
    }

    // MARK: - Message Handling

    /// Presents an iPhone-started workout the starter accepted (ADR-006).
    private func presentRequestedWorkout(_ request: StartRequest) {
        workoutStarter.requestPresented()
        // A time-boxed workout needs a duration. One without it can't have come from this
        // app's iPhone side; presenting it would build a timer that can't run.
        let config = request.config
        guard !config.kind.hasFixedDuration || (config.totalDuration ?? 0) > 0 else {
            Logger.timerSync.error("Ignoring a \(config.kind.rawValue) start request without a duration")
            return
        }
        activeTimer = TimerPresentation(
            config: config,
            workoutID: request.workoutID,
            startedOnPhone: true
        )
    }
}

#Preview {
    NavigationStack {
        WatchPresetListView()
    }
    .modelContainer(for: TimerPreset.self, inMemory: true)
}
