//
//  Kraftli_TimersApp.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 17.12.2025.
//

import SwiftUI
import SwiftData
import os

@main
struct Kraftli_TimersApp: App {
    let modelContainer: ModelContainer
    @State private var settings = AppSettings()
    @State private var mirroredWorkoutObserver = MirroredWorkoutObserver()

    // Capture launch screen preference once at startup (not reactive to mid-session changes)
    @State private var showLaunchScreen: Bool

    /// HealthKit service for workout operations and mirrored session handling.
    private let healthKitService: any HealthKitService = DefaultHealthKitService()

    init() {
        // Load exercise reference data from JSON (in-memory, not persisted)
        ExerciseRepository.load()

        // Activate WatchConnectivity for real-time sync with Watch
        WatchConnectivityService.shared.activate()

        // Determine if launch screen should show (before settings is fully initialized)
        let launchEnabled = UserDefaults.standard.object(forKey: "launchScreenEnabled") as? Bool ?? true
        _showLaunchScreen = State(initialValue: launchEnabled)

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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container

            // Migrate exercise relationships to exerciseId
            Self.migrateExerciseRelationships(in: container.mainContext)

            // Remove CloudKit duplicates (same UUID synced from multiple devices)
            Self.deduplicatePresets(in: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(settings)
                    .environment(mirroredWorkoutObserver)

                if showLaunchScreen {
                    LaunchScreenView {
                        showLaunchScreen = false
                    }
                    .zIndex(1)
                }
            }
            .onAppear {
                // Set up mirrored workout session handler (Scenario D: Watch-initiated workouts).
                // When Watch starts a workout and mirrors to iPhone, this handler receives
                // the session. We store it in MirroredWorkoutObserver so iPhone can observe
                // state changes (pause/resume/end) — even when WCSession messages are lost.
                healthKitService.setupMirroringHandler { session in
                    Logger.healthKit.info("Received mirrored workout session from Watch")
                    mirroredWorkoutObserver.setSession(session)
                }
            }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Deduplication

    /// Removes CloudKit duplicates where the same preset UUID appears more than once.
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
    /// This allows us to stop persisting exercises while keeping preset data intact.
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
}
