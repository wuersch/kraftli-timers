//
//  WatchPresetListView.swift
//  Kraftli Timers Watch App
//
//  Displays synced timer presets from CloudKit.
//  Tap a preset to launch the appropriate timer.
//

import SwiftUI
import SwiftData

struct WatchPresetListView: View {
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    @State private var selectedPreset: TimerPreset?
    @State private var showEMOMTimer = false
    @State private var showAMRAPTimer = false

    // Quick timer state (default timers when no preset selected)
    @State private var showQuickEMOM = false
    @State private var showQuickAMRAP = false

    var body: some View {
        List {
            // Quick Timers - always available for standalone use
            Section("Quick Start") {
                Button {
                    showQuickEMOM = true
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
                    showQuickAMRAP = true
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
                            selectedPreset = preset
                            if preset.kind == .emom {
                                showEMOMTimer = true
                            } else {
                                showAMRAPTimer = true
                            }
                        } label: {
                            WatchPresetRowView(preset: preset)
                        }
                    }
                }
            }
        }
        .navigationTitle("Timers")
        // Quick timers (default durations)
        .fullScreenCover(isPresented: $showQuickEMOM) {
            WatchEMOMTimerView(totalDuration: 5 * 60, intervalDuration: 30)
        }
        .fullScreenCover(isPresented: $showQuickAMRAP) {
            WatchAMRAPTimerView(totalDuration: 5 * 60)
        }
        // Preset timers
        .fullScreenCover(isPresented: $showEMOMTimer) {
            if let preset = selectedPreset {
                WatchEMOMTimerView(
                    totalDuration: preset.durationInterval,
                    intervalDuration: preset.intervalDuration,
                    exerciseName: preset.exercise?.name ?? "EMOM Workout"
                )
            }
        }
        .fullScreenCover(isPresented: $showAMRAPTimer) {
            if let preset = selectedPreset {
                WatchAMRAPTimerView(
                    totalDuration: preset.durationInterval,
                    exerciseName: preset.exercise?.name ?? "AMRAP Workout"
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
