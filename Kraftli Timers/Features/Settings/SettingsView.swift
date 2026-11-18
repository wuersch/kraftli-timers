//
//  SettingsView.swift
//  Kraftli Timers
//
//  Main settings screen with Audio, Visuals, Data Management, and About sections.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var workouts: [WorkoutLog]
    @Query private var presets: [TimerPreset]
    @Query private var sessions: [TrainingSession]
    @Query private var weekPlans: [WeekPlan]

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
                    sessionCount: sessions.count,
                    onClearWorkouts: clearWorkouts,
                    onClearPresets: clearPresets,
                    onClearSessions: clearSessions,
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
        workouts.forEach(modelContext.delete)
        saveContext()
    }

    private func clearPresets() {
        presets.forEach(modelContext.delete)
        saveContext()
    }

    /// Sessions go together with the week plan that refers to them (UC-0011).
    private func clearSessions() {
        deleteSessionsAndWeekPlans()
        saveContext()
    }

    private func deleteSessionsAndWeekPlans() {
        sessions.forEach(modelContext.delete)
        weekPlans.forEach(modelContext.delete)
    }

    private func clearAll() {
        workouts.forEach(modelContext.delete)
        presets.forEach(modelContext.delete)
        deleteSessionsAndWeekPlans()
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
