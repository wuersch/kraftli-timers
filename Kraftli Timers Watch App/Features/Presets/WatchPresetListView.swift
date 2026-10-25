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

/// Captures all timer configuration at tap time, ensuring data is available when the cover presents.
/// This avoids SwiftUI state timing issues with `fullScreenCover(isPresented:)`.
enum TimerPresentation: Identifiable, Equatable {
    // Both run through the timer session (ADR-006), started on either device.
    case emom(
        duration: TimeInterval,
        intervalCount: Int,
        exerciseName: String,
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false
    )
    case amrap(
        duration: TimeInterval,
        exerciseName: String,
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false
    )

    // The correlation ID is part of the identity: a new iPhone-led start for the
    // same preset must re-create the timer view (fresh scheduledStartTime), not
    // reuse the already-started one.
    var id: String {
        switch self {
        case .emom(_, _, _, let workoutID, _):
            return "emom-\(workoutID.uuidString)"
        case .amrap(_, _, let workoutID, _):
            return "amrap-\(workoutID.uuidString)"
        }
    }

    /// Extracts the correlation ID from the timer presentation.
    var correlationID: UUID? {
        switch self {
        case .emom(_, _, _, let workoutID, _): return workoutID
        case .amrap(_, _, let workoutID, _): return workoutID
        }
    }
}

// MARK: - WatchPresetListView

struct WatchPresetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchMessageCoordinator.self) private var messageCoordinator
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
            // Consume any message that arrived before the view existed (race fix)
            if let message = messageCoordinator.pendingStartTimer {
                messageCoordinator.pendingStartTimer = nil
                handleStartTimer(message)
            }
            if let request = workoutStarter.requestedWorkout {
                presentRequestedWorkout(request)
            }
        }
        .onChange(of: workoutStarter.requestedWorkout) { _, request in
            guard let request else { return }
            presentRequestedWorkout(request)
        }
        .onChange(of: messageCoordinator.pendingStartTimer) { _, newMessage in
            // Handle messages arriving while the view is already visible
            guard let message = newMessage else { return }
            messageCoordinator.pendingStartTimer = nil
            handleStartTimer(message)
        }
        .fullScreenCover(item: $activeTimer) { timer in
            switch timer {
            case .emom(let duration, let intervalCount, let exerciseName, let workoutID, let startedOnPhone):
                WatchEMOMTimerView(
                    totalDuration: duration,
                    intervalCount: intervalCount,
                    exerciseName: exerciseName,
                    workoutID: workoutID,
                    startedOnPhone: startedOnPhone
                )
            case .amrap(let duration, let exerciseName, let workoutID, let startedOnPhone):
                WatchAMRAPTimerView(
                    totalDuration: duration,
                    exerciseName: exerciseName,
                    workoutID: workoutID,
                    startedOnPhone: startedOnPhone
                )
            }
        }
        .onChange(of: activeTimer) { _, newValue in
            // Tell the coordinator a timer is on screen, so a stale legacy stop can't end
            // its workout. Timers run on the timer session now, not a legacy sync service.
            if let timer = newValue {
                messageCoordinator.isTimerPresented = true
                messageCoordinator.activeCorrelationID = timer.correlationID
            } else {
                messageCoordinator.isTimerPresented = false
                messageCoordinator.activeCorrelationID = nil
            }
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

    private func launchTimer(for preset: TimerPreset) {
        if preset.kind == .emom {
            activeTimer = .emom(
                duration: preset.durationInterval,
                intervalCount: preset.targetReps ?? 1,
                exerciseName: preset.exerciseInfo?.name ?? "EMOM Workout"
            )
        } else {
            activeTimer = .amrap(
                duration: preset.durationInterval,
                exerciseName: preset.exerciseInfo?.name ?? "AMRAP Workout"
            )
        }
    }

    private func deletePreset(_ preset: TimerPreset) {
        modelContext.delete(preset)
    }

    // MARK: - Message Handling

    /// Handles a legacy timer start message from iPhone. Both timer kinds now start
    /// through a `StartRequest` (ADR-006), so the message no longer presents anything.
    @MainActor
    private func handleStartTimer(_ message: StartTimerMessage) {
        Logger.timerSync.info("Ignoring legacy StartTimerMessage: \(message.exerciseName)")
    }

    /// Presents an iPhone-started workout the starter accepted (ADR-006).
    private func presentRequestedWorkout(_ request: StartRequest) {
        workoutStarter.requestPresented()
        switch TimerKind(rawValue: request.config.timerKindRaw) ?? .emom {
        case .emom:
            activeTimer = .emom(
                duration: request.config.totalDuration,
                intervalCount: request.config.intervalCount ?? 1,
                exerciseName: request.config.exerciseName,
                workoutID: request.workoutID,
                startedOnPhone: true
            )
        case .amrap:
            activeTimer = .amrap(
                duration: request.config.totalDuration,
                exerciseName: request.config.exerciseName,
                workoutID: request.workoutID,
                startedOnPhone: true
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchPresetListView()
    }
    .modelContainer(for: TimerPreset.self, inMemory: true)
}
