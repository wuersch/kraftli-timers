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

    /// Routes Watch messages for the whole app lifetime.
    /// Created at startup so the handler exists before any message arrives.
    @State private var phoneMessageCoordinator = PhoneMessageCoordinator()

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
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
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
                    .environment(phoneMessageCoordinator)

                if showLaunchScreen {
                    LaunchScreenView {
                        showLaunchScreen = false
                    }
                    .zIndex(1)
                }
            }
            .task {
                // Run data migrations after the UI is up to minimize SQLite lock time
                // during launch. Holding a DB lock while suspended causes 0xdead10cc kills.
                // iPhone is the primary device: it alone deletes CloudKit duplicates.
                PresetMaintenance.performStartupMaintenance(
                    in: modelContainer.mainContext,
                    deletesDuplicates: true
                )
            }
            .onAppear {
                // Wire the model context so Watch messages can update WorkoutLogs
                // even when no timer view is alive.
                phoneMessageCoordinator.modelContext = modelContainer.mainContext

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
}
