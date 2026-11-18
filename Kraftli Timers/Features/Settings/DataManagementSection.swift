//
//  DataManagementSection.swift
//  Kraftli Timers
//
//  Settings section for clearing app data.
//

import SwiftUI

struct DataManagementSection: View {
    let workoutCount: Int
    let presetCount: Int
    let sessionCount: Int
    let onClearWorkouts: () -> Void
    let onClearPresets: () -> Void
    let onClearSessions: () -> Void
    let onClearAll: () -> Void

    @State private var showingClearWorkoutsAlert = false
    @State private var showingClearPresetsAlert = false
    @State private var showingClearSessionsAlert = false
    @State private var showingClearAllAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Your Data")
                .font(.headline)

            VStack(spacing: 0) {
                // Clear Workouts
                Button {
                    showingClearWorkoutsAlert = true
                } label: {
                    HStack {
                        Text("Clear Workout History")
                            .foregroundStyle(workoutCount > 0 ? .red : .secondary)
                        Spacer()
                        Text("\(workoutCount)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .disabled(workoutCount == 0)

                Divider().padding(.leading, 16)

                // Clear Presets
                Button {
                    showingClearPresetsAlert = true
                } label: {
                    HStack {
                        Text("Clear Timer Presets")
                            .foregroundStyle(presetCount > 0 ? .red : .secondary)
                        Spacer()
                        Text("\(presetCount)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .disabled(presetCount == 0)

                Divider().padding(.leading, 16)

                // Clear Sessions (with the week plan)
                Button {
                    showingClearSessionsAlert = true
                } label: {
                    HStack {
                        Text("Clear Sessions")
                            .foregroundStyle(sessionCount > 0 ? .red : .secondary)
                        Spacer()
                        Text("\(sessionCount)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .disabled(sessionCount == 0)

                Divider().padding(.leading, 16)

                // Clear All
                Button {
                    showingClearAllAlert = true
                } label: {
                    HStack {
                        Text("Clear All Data")
                            .foregroundStyle(totalCount > 0 ? .red : .secondary)
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .disabled(totalCount == 0)
            }
            .cardStyle(padded: false)
        }
        .alert("Clear Workout History", isPresented: $showingClearWorkoutsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive, action: onClearWorkouts)
        } message: {
            Text("This will permanently delete all \(workoutCount) workout records. This action cannot be undone.")
        }
        .alert("Clear Timer Presets", isPresented: $showingClearPresetsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive, action: onClearPresets)
        } message: {
            Text("This will permanently delete all \(presetCount) timer presets. This action cannot be undone.")
        }
        .alert("Clear Sessions", isPresented: $showingClearSessionsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive, action: onClearSessions)
        } message: {
            Text("This will permanently delete all \(sessionCount) sessions and your week plan. This action cannot be undone.")
        }
        .alert("Clear All Data", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive, action: onClearAll)
        } message: {
            Text("This will permanently delete all workouts, presets and sessions. This action cannot be undone.")
        }
    }

    private var totalCount: Int {
        workoutCount + presetCount + sessionCount
    }
}

// MARK: - Preview

#Preview("With Data") {
    ScrollView {
        DataManagementSection(
            workoutCount: 42,
            presetCount: 5,
            sessionCount: 3,
            onClearWorkouts: {},
            onClearPresets: {},
            onClearSessions: {},
            onClearAll: {}
        )
        .padding()
    }
}

#Preview("Empty") {
    ScrollView {
        DataManagementSection(
            workoutCount: 0,
            presetCount: 0,
            sessionCount: 0,
            onClearWorkouts: {},
            onClearPresets: {},
            onClearSessions: {},
            onClearAll: {}
        )
        .padding()
    }
}
