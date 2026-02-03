//
//  Kraftli_Timers_WatchApp.swift
//  Kraftli Timers Watch App
//
//  Created by Michael Würsch on 18.01.2026.
//

import SwiftUI
import SwiftData
import WatchConnectivity

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

            // Wire up preset sync from iPhone via WatchConnectivity
            Self.setupPresetSyncHandler(with: modelContainer.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Preset Sync

    @MainActor
    private static func setupPresetSyncHandler(with context: ModelContext) {
        WatchConnectivityService.shared.onPresetsReceived = { presets in
            Task { @MainActor in
                syncPresets(presets, in: context)
            }
        }
    }

    @MainActor
    private static func syncPresets(_ received: [PresetTransferData], in context: ModelContext) {
        // Build lookup of received presets by ID
        let receivedById = Dictionary(uniqueKeysWithValues: received.map { ($0.id, $0) })

        // Fetch existing presets
        let descriptor = FetchDescriptor<TimerPreset>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        // Update or create presets using exerciseId (no longer using Exercise relationship)
        for data in received {
            // Look up exercise ID from repository by name
            let exerciseId = data.exerciseName.flatMap { ExerciseRepository.exercise(byName: $0)?.id }

            if let preset = existingById[data.id] {
                // Update existing preset
                preset.kindRawValue = data.kind
                preset.durationInterval = data.duration
                preset.targetReps = data.targetReps
                preset.sortOrder = data.sortOrder
                preset.exerciseId = exerciseId
            } else {
                // Create new preset
                let preset = TimerPreset(
                    id: data.id,
                    kind: TimerKind(rawValue: data.kind) ?? .emom,
                    durationInterval: data.duration,
                    targetReps: data.targetReps,
                    sortOrder: data.sortOrder,
                    exerciseId: exerciseId
                )
                context.insert(preset)
            }
        }

        // Delete presets that no longer exist on iPhone
        for preset in existing where receivedById[preset.id] == nil {
            context.delete(preset)
        }

        try? context.save()
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
