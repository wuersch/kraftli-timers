//
//  SettingsView.swift
//  Kraftli Timers
//
//  Main settings screen with Audio, Visuals, Data Management, and About sections.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @Query private var workouts: [WorkoutLog]
    @Query private var presets: [TimerPreset]

    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AudioSection()
                VisualsSection()
                DataManagementSection(
                    workoutCount: workouts.count,
                    presetCount: presets.count,
                    onClearWorkouts: clearWorkouts,
                    onClearPresets: clearPresets,
                    onClearAll: clearAll
                )
                AboutSection()
            }
            .padding()
        }
        .navigationTitle("Settings")
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func clearWorkouts() {
        for workout in workouts {
            modelContext.delete(workout)
        }
        saveContext()
    }

    private func clearPresets() {
        for preset in presets {
            modelContext.delete(preset)
        }
        saveContext()
    }

    private func clearAll() {
        for workout in workouts {
            modelContext.delete(workout)
        }
        for preset in presets {
            modelContext.delete(preset)
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save changes. Please try again."
            showingErrorAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppSettings())
    .modelContainer(for: [WorkoutLog.self, TimerPreset.self], inMemory: true)
}
