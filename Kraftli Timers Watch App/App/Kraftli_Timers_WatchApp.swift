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
    let modelContainer: ModelContainer

    /// Coordinates message handling with iPhone.
    /// Created at app startup to ensure handlers are ready before any messages arrive.
    @State private var messageCoordinator = WatchMessageCoordinator()

    init() {
        // Activate WatchConnectivity for real-time sync with iPhone
        WatchConnectivityService.shared.activate()

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

            // Seed exercises locally (reference data, works without CloudKit)
            Self.seedExercisesIfNeeded(in: modelContainer.mainContext)

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

        // Fetch exercises for linking
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let exercises = (try? context.fetch(exerciseDescriptor)) ?? []
        let exercisesByName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        // Update or create presets
        for data in received {
            if let preset = existingById[data.id] {
                // Update existing preset
                preset.kindRawValue = data.kind
                preset.durationInterval = data.duration
                preset.targetReps = data.targetReps
                preset.sortOrder = data.sortOrder
                preset.exercise = data.exerciseName.flatMap { exercisesByName[$0] }
            } else {
                // Create new preset
                let preset = TimerPreset(
                    id: data.id,
                    kind: TimerKind(rawValue: data.kind) ?? .emom,
                    durationInterval: data.duration,
                    targetReps: data.targetReps,
                    sortOrder: data.sortOrder,
                    exercise: data.exerciseName.flatMap { exercisesByName[$0] }
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

    // MARK: - Data Seeding

    @MainActor
    private static func seedExercisesIfNeeded(in context: ModelContext) {
        let exerciseDataList = ExerciseLoader.loadBundled()

        for data in exerciseDataList {
            // Skip if exercise already exists (from CloudKit or previous seeding)
            let existingId = data.id
            let predicate = #Predicate<Exercise> { $0.id == existingId }
            let descriptor = FetchDescriptor<Exercise>(predicate: predicate)

            if (try? context.fetchCount(descriptor)) == 0 {
                let exercise = Exercise(from: data)
                context.insert(exercise)
            }
        }

        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(messageCoordinator)
        }
        .modelContainer(modelContainer)
    }
}
