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

    /// Coordinates message handling with iPhone.
    /// Created at app startup to ensure handlers are ready before any messages arrive.
    @State private var messageCoordinator = WatchMessageCoordinator()

    init() {
        // Load exercise reference data from JSON (in-memory, not persisted)
        ExerciseRepository.load()

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
                .environment(messageCoordinator)
                .environment(appDelegate.workoutSessionManager)
                .onAppear {
                    // Wire session manager so coordinator can end orphaned sessions
                    messageCoordinator.sessionManager = appDelegate.workoutSessionManager
                }
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
