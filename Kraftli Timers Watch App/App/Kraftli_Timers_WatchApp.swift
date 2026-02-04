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

            // Migrate exercise relationships to exerciseId
            Self.migrateExerciseRelationships(in: modelContainer.mainContext)

            // Remove CloudKit duplicates (same UUID synced from multiple devices)
            Self.deduplicatePresets(in: modelContainer.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Deduplication

    /// Removes CloudKit duplicates where the same preset UUID appears more than once.
    @MainActor
    private static func deduplicatePresets(in context: ModelContext) {
        let descriptor = FetchDescriptor<TimerPreset>()
        guard let presets = try? context.fetch(descriptor) else { return }

        var seen: Set<UUID> = []
        var didDelete = false
        for preset in presets {
            if seen.contains(preset.id) {
                context.delete(preset)
                didDelete = true
            } else {
                seen.insert(preset.id)
            }
        }

        if didDelete {
            try? context.save()
        }
    }

    // MARK: - Migration

    /// Migrates presets from exercise relationship to exerciseId.
    @MainActor
    private static func migrateExerciseRelationships(in context: ModelContext) {
        let descriptor = FetchDescriptor<TimerPreset>()
        guard let presets = try? context.fetch(descriptor) else { return }

        var migrated = false
        for preset in presets {
            // If has relationship but no ID, migrate
            if let exercise = preset.exercise, preset.exerciseId == nil {
                preset.exerciseId = exercise.id
                migrated = true
            }
        }

        if migrated {
            try? context.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(messageCoordinator)
                .environment(appDelegate.workoutSessionManager)
        }
        .modelContainer(modelContainer)
    }
}
