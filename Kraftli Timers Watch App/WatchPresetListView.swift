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
    case emom(duration: TimeInterval, intervalDuration: TimeInterval, exerciseName: String)
    case amrap(duration: TimeInterval, exerciseName: String)

    var id: String {
        switch self {
        case .quickEMOM: return "quick-emom"
        case .quickAMRAP: return "quick-amrap"
        case .emom(let duration, let interval, _): return "emom-\(duration)-\(interval)"
        case .amrap(let duration, _): return "amrap-\(duration)"
        }
    }
}

// MARK: - WatchPresetListView

struct WatchPresetListView: View {
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    /// The currently presented timer, if any. Using item-based presentation
    /// guarantees data is captured before the cover appears.
    @State private var activeTimer: TimerPresentation?

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
        .fullScreenCover(item: $activeTimer) { timer in
            switch timer {
            case .quickEMOM:
                WatchEMOMTimerView(totalDuration: 5 * 60, intervalDuration: 30)
            case .quickAMRAP:
                WatchAMRAPTimerView(totalDuration: 5 * 60)
            case .emom(let duration, let intervalDuration, let exerciseName):
                WatchEMOMTimerView(
                    totalDuration: duration,
                    intervalDuration: intervalDuration,
                    exerciseName: exerciseName
                )
            case .amrap(let duration, let exerciseName):
                WatchAMRAPTimerView(
                    totalDuration: duration,
                    exerciseName: exerciseName
                )
            }
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
