//
//  WatchPresetListView.swift
//  Kraftli Timers Watch App
//
//  Displays synced timer presets from CloudKit.
//  Tap a preset to launch the appropriate timer.
//

import SwiftUI
import SwiftData

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
    case emom(
        duration: TimeInterval,
        intervalCount: Int,
        exerciseName: String,
        displayOnly: Bool = false,
        scheduledStartTime: Date? = nil,
        correlationID: UUID? = nil
    )
    case amrap(
        duration: TimeInterval,
        exerciseName: String,
        displayOnly: Bool = false,
        scheduledStartTime: Date? = nil,
        correlationID: UUID? = nil
    )

    var id: String {
        switch self {
        case .emom(let duration, let count, _, _, _, _): return "emom-\(duration)-\(count)"
        case .amrap(let duration, _, _, _, _): return "amrap-\(duration)"
        }
    }

    /// Extracts the correlation ID from the timer presentation.
    var correlationID: UUID? {
        switch self {
        case .emom(_, _, _, _, _, let id): return id
        case .amrap(_, _, _, _, let id): return id
        }
    }

    /// Creates a TimerPresentation from a StartTimerMessage received from iPhone.
    static func fromMessage(_ message: StartTimerMessage) -> TimerPresentation {
        switch message.timerKind {
        case .emom:
            return .emom(
                duration: message.totalDuration,
                intervalCount: message.intervalCount ?? 1,
                exerciseName: message.exerciseName,
                displayOnly: message.displayOnly,
                scheduledStartTime: message.scheduledStartTime,
                correlationID: message.correlationID
            )
        case .amrap:
            return .amrap(
                duration: message.totalDuration,
                exerciseName: message.exerciseName,
                displayOnly: message.displayOnly,
                scheduledStartTime: message.scheduledStartTime,
                correlationID: message.correlationID
            )
        }
    }
}

// MARK: - WatchPresetListView

struct WatchPresetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchMessageCoordinator.self) private var messageCoordinator
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    /// The currently presented timer, if any. Using item-based presentation
    /// guarantees data is captured before the cover appears.
    @State private var activeTimer: TimerPresentation?

    /// The currently presented editor sheet, if any.
    @State private var activeEditor: ActiveEditor?

    /// Sync service for mirrored timers (started from iPhone).
    /// Created when receiving a StartTimerMessage, nil for standalone timers.
    @State private var syncService: DefaultWatchTimerSyncService?

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
        }
        .onChange(of: messageCoordinator.pendingStartTimer) { _, newMessage in
            // Handle messages arriving while the view is already visible
            guard let message = newMessage else { return }
            messageCoordinator.pendingStartTimer = nil
            handleStartTimer(message)
        }
        .fullScreenCover(item: $activeTimer) { timer in
            switch timer {
            case .emom(let duration, let intervalCount, let exerciseName, let displayOnly, let scheduledStartTime, let correlationID):
                WatchEMOMTimerView(
                    totalDuration: duration,
                    intervalCount: intervalCount,
                    exerciseName: exerciseName,
                    displayOnly: displayOnly,
                    syncService: syncService ?? DefaultWatchTimerSyncService(),
                    scheduledStartTime: scheduledStartTime,
                    correlationID: correlationID
                )
            case .amrap(let duration, let exerciseName, let displayOnly, let scheduledStartTime, let correlationID):
                WatchAMRAPTimerView(
                    totalDuration: duration,
                    exerciseName: exerciseName,
                    displayOnly: displayOnly,
                    syncService: syncService ?? DefaultWatchTimerSyncService(),
                    scheduledStartTime: scheduledStartTime,
                    correlationID: correlationID
                )
            }
        }
        .onChange(of: activeTimer) { _, newValue in
            // Update coordinator's active sync service and correlation ID
            // when timer is presented/dismissed
            if let timer = newValue {
                messageCoordinator.activeSyncService = syncService
                messageCoordinator.activeCorrelationID = timer.correlationID
            } else {
                messageCoordinator.activeSyncService = nil
                messageCoordinator.activeCorrelationID = nil
                syncService = nil
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

    /// Handles a timer start message from iPhone.
    @MainActor
    private func handleStartTimer(_ message: StartTimerMessage) {
        // Create sync service for mirrored timer (enables bidirectional control)
        syncService = DefaultWatchTimerSyncService()
        // Present the timer
        activeTimer = TimerPresentation.fromMessage(message)
    }
}

#Preview {
    NavigationStack {
        WatchPresetListView()
    }
    .modelContainer(for: TimerPreset.self, inMemory: true)
}
