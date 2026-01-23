//
//  WatchPresetListView.swift
//  Kraftli Timers Watch App
//
//  Displays synced timer presets from CloudKit.
//  Tap a preset to launch the appropriate timer.
//

import SwiftUI
import SwiftData

// MARK: - Timer Presentation Model

/// Captures all timer configuration at tap time, ensuring data is available when the cover presents.
/// This avoids SwiftUI state timing issues with `fullScreenCover(isPresented:)`.
enum TimerPresentation: Identifiable {
    case quickEMOM
    case quickAMRAP
    case emom(duration: TimeInterval, intervalDuration: TimeInterval, exerciseName: String, displayOnly: Bool = false)
    case amrap(duration: TimeInterval, exerciseName: String, displayOnly: Bool = false)

    var id: String {
        switch self {
        case .quickEMOM: return "quick-emom"
        case .quickAMRAP: return "quick-amrap"
        case .emom(let duration, let interval, _, _): return "emom-\(duration)-\(interval)"
        case .amrap(let duration, _, _): return "amrap-\(duration)"
        }
    }

    /// Creates a TimerPresentation from a StartTimerMessage received from iPhone.
    static func fromMessage(_ message: StartTimerMessage) -> TimerPresentation {
        switch message.timerKind {
        case .emom:
            return .emom(
                duration: message.totalDuration,
                intervalDuration: message.intervalDuration ?? 60,
                exerciseName: message.exerciseName,
                displayOnly: message.displayOnly
            )
        case .amrap:
            return .amrap(
                duration: message.totalDuration,
                exerciseName: message.exerciseName,
                displayOnly: message.displayOnly
            )
        }
    }
}

// MARK: - WatchPresetListView

struct WatchPresetListView: View {
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    /// The currently presented timer, if any. Using item-based presentation
    /// guarantees data is captured before the cover appears.
    @State private var activeTimer: TimerPresentation?

    /// Sync service for mirrored timers (started from iPhone).
    /// Created when receiving a StartTimerMessage, nil for standalone timers.
    @State private var syncService: DefaultWatchTimerSyncService?

    var body: some View {
        List {
            // Quick Timers - always available for standalone use
            Section("Quick Start") {
                Button {
                    activeTimer = .quickEMOM
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick EMOM")
                            .font(.headline)
                        Text("5 min · 10 intervals")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    activeTimer = .quickAMRAP
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick AMRAP")
                            .font(.headline)
                        Text("5 min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Synced presets from iPhone
            if !presets.isEmpty {
                Section("My Presets") {
                    ForEach(presets) { preset in
                        Button {
                            if preset.kind == .emom {
                                activeTimer = .emom(
                                    duration: preset.durationInterval,
                                    intervalDuration: preset.intervalDuration,
                                    exerciseName: preset.exercise?.name ?? "EMOM Workout"
                                )
                            } else {
                                activeTimer = .amrap(
                                    duration: preset.durationInterval,
                                    exerciseName: preset.exercise?.name ?? "AMRAP Workout"
                                )
                            }
                        } label: {
                            WatchPresetRowView(preset: preset)
                        }
                    }
                }
            }
        }
        .navigationTitle("Timers")
        .onAppear {
            setupMessageHandling()
        }
        .fullScreenCover(item: $activeTimer) { timer in
            switch timer {
            case .quickEMOM:
                WatchEMOMTimerView(totalDuration: 5 * 60, intervalDuration: 30)
            case .quickAMRAP:
                WatchAMRAPTimerView(totalDuration: 5 * 60)
            case .emom(let duration, let intervalDuration, let exerciseName, let displayOnly):
                WatchEMOMTimerView(
                    totalDuration: duration,
                    intervalDuration: intervalDuration,
                    exerciseName: exerciseName,
                    displayOnly: displayOnly,
                    syncService: displayOnly ? syncService : nil
                )
            case .amrap(let duration, let exerciseName, let displayOnly):
                WatchAMRAPTimerView(
                    totalDuration: duration,
                    exerciseName: exerciseName,
                    displayOnly: displayOnly,
                    syncService: displayOnly ? syncService : nil
                )
            }
        }
        .onDisappear {
            // Clean up sync service when view is dismissed
            syncService = nil
        }
    }

    // MARK: - Message Handling

    /// Sets up the callback to receive timer start messages from iPhone.
    ///
    /// Note: This captures `self` (a struct), but `@State` properties use external
    /// storage managed by SwiftUI, so mutations work correctly across captures.
    private func setupMessageHandling() {
        WatchConnectivityService.shared.onMessageReceived = { message in
            handleMessage(message)
        }
    }

    /// Handles incoming messages from iPhone.
    @MainActor
    private func handleMessage(_ message: WatchMessage) {
        switch message {
        case let startTimer as StartTimerMessage:
            // Create sync service for mirrored timer (enables bidirectional control)
            syncService = DefaultWatchTimerSyncService()
            // Present the timer and start it immediately
            activeTimer = TimerPresentation.fromMessage(startTimer)
        default:
            // Unknown message type - ignore for now
            break
        }
    }
}

// MARK: - TimerPreset Extension

private extension TimerPreset {
    /// Calculates interval duration for EMOM (total duration / reps).
    var intervalDuration: TimeInterval {
        guard let reps = targetReps, reps > 0 else {
            return 60 // Default 1 minute intervals
        }
        return durationInterval / Double(reps)
    }
}

#Preview {
    NavigationStack {
        WatchPresetListView()
    }
    .modelContainer(for: TimerPreset.self, inMemory: true)
}
