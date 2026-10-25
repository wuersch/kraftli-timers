//
//  Kraftli_Timers_WatchApp.swift
//  Kraftli Timers Watch App
//
//  Created by Michael Würsch on 18.01.2026.
//

import SwiftUI
import SwiftData

@main
struct Kraftli_Timers_Watch_AppApp: App {
    /// Receives HKWorkoutConfiguration from iPhone and owns the shared WorkoutSessionManager.
    @WKApplicationDelegateAdaptor private var appDelegate: WorkoutAppDelegate

    let modelContainer: ModelContainer

    init() {
        // Load exercise reference data from JSON (in-memory, not persisted)
        ExerciseRepository.load()

        // Create the timer session (and its WatchConnectivity handler) before activating,
        // so a start request in the persisted application context isn't dropped.
        _ = WatchTimerRuntime.shared

        // Activate WatchConnectivity for real-time sync with iPhone
        WatchConnectivityService.shared.activate()

        // Keep Exercise.self in schema for migration (reading old relationship data)
        let schema = Schema([
            Exercise.self,
            TimerPreset.self,
            WorkoutLog.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.ch.omnom.kraftli.timers")
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.workoutSessionManager)
                .environment(WatchTimerRuntime.shared.timerSession)
                .environment(WatchTimerRuntime.shared.starter)
                .task {
                    // Run data maintenance after the UI is up, never in App.init: the
                    // Watch is routinely background-cold-launched and can be suspended
                    // mid-launch holding the SQLite write lock (0xdead10cc), which would
                    // kill the launch before an iPhone→Watch handoff is handled.
                    // deletesDuplicates: false — only the iPhone deletes CloudKit
                    // duplicates, so two devices can never cross-delete both copies.
                    PresetMaintenance.performStartupMaintenance(
                        in: modelContainer.mainContext,
                        deletesDuplicates: false
                    )

                    // Clean up any orphaned HKWorkoutSession from a previous crash/force-quit
                    await appDelegate.workoutSessionManager.cleanupOrphanedSessionIfNeeded()
                }
        }
        .modelContainer(modelContainer)
    }
}
