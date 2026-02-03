//
//  Kraftli_TimersApp.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 17.12.2025.
//

import SwiftUI
import SwiftData
import WatchConnectivity

@main
struct Kraftli_TimersApp: App {
    let modelContainer: ModelContainer
    @State private var settings = AppSettings()

    // Capture launch screen preference once at startup (not reactive to mid-session changes)
    @State private var showLaunchScreen: Bool

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
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(settings)

                if showLaunchScreen {
                    LaunchScreenView {
                        showLaunchScreen = false
                    }
                    .zIndex(1)
                }
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                syncPresetsToWatch()
            }
        }
    }

    // MARK: - WatchConnectivity Sync

    private func syncPresetsToWatch() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<TimerPreset>(sortBy: [SortDescriptor(\.sortOrder)])

        guard let presets = try? context.fetch(descriptor) else { return }

        let transferData = presets.map { PresetTransferData(from: $0) }
        WatchConnectivityService.shared.sendPresetsToWatch(transferData)
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
