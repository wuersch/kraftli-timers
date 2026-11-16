//
//  Kraftli_TimersApp.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 17.12.2025.
//

import SwiftUI
import SwiftData

@main
struct Kraftli_TimersApp: App {
    let modelContainer: ModelContainer
    @State private var settings = AppSettings()

    /// The workout objects that live as long as the app (ADR-006).
    private let runtime: PhoneTimerRuntime

    // Capture launch screen preference once at startup (not reactive to mid-session changes)
    @State private var showLaunchScreen: Bool

    init() {
        // Load exercise reference data from JSON (in-memory, not persisted)
        ExerciseRepository.load()

        // Determine if launch screen should show (before settings is fully initialized)
        _showLaunchScreen = State(initialValue: AppSettings.isLaunchScreenEnabled)

        // Exercise.self is unused but stays in the schema: CloudKit schema changes are additive only (ADR-0008)
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
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        runtime = PhoneTimerRuntime(modelContext: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(settings)
                    .environment(runtime.messageCoordinator)
                    .environment(runtime.timerSession)
                    .environment(runtime.workoutStarter)
                    .environment(\.workoutRecorder, runtime.workoutRecorder)

                if showLaunchScreen {
                    LaunchScreenView {
                        showLaunchScreen = false
                    }
                    .zIndex(1)
                }
            }
            .task {
                // Run data maintenance after the UI is up to minimize SQLite lock time
                // during launch. Holding a DB lock while suspended causes 0xdead10cc kills.
                // iPhone is the primary device: it alone deletes CloudKit duplicates.
                PresetMaintenance.performStartupMaintenance(
                    in: modelContainer.mainContext,
                    deletesDuplicates: true
                )
            }
        }
        .modelContainer(modelContainer)
    }
}
