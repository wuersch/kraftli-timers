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
    /// Holds the Watch's mirrored workout session for the HealthKit sync channel.
    private let mirroredWorkoutObserver: MirroredWorkoutObserver

    /// The app's one timer session (ADR-006). One instance for the app's lifetime, because
    /// its WatchConnectivity transport is the only receiver of timer sync payloads.
    @State private var timerSession: TimerSessionController

    /// Starts iPhone-initiated workouts through the Watch handshake (ADR-006 §4).
    @State private var workoutStarter: PhoneWorkoutStarter

    /// Routes Watch messages for the whole app lifetime.
    /// Created in `init` (with the model context already wired) so the handler exists before any
    /// message arrives — including a background WCSession launch with no scene.
    @State private var phoneMessageCoordinator: PhoneMessageCoordinator

    // Capture launch screen preference once at startup (not reactive to mid-session changes)
    @State private var showLaunchScreen: Bool

    init() {
        // Load exercise reference data from JSON (in-memory, not persisted)
        ExerciseRepository.load()

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

        // Create the message coordinator with the model context already wired, so a Watch
        // WorkoutSessionEndedMessage can link its HealthKit UUID to the WorkoutLog even on a
        // background WCSession launch (terminated app, no scene → the WindowGroup's onAppear,
        // where this used to be wired, never fires).
        _phoneMessageCoordinator = State(
            initialValue: PhoneMessageCoordinator(modelContext: modelContainer.mainContext)
        )

        let healthKitService = DefaultHealthKitService()
        let mirroredWorkoutObserver = MirroredWorkoutObserver()
        self.mirroredWorkoutObserver = mirroredWorkoutObserver

        // Timer sync (ADR-006): publish on WatchConnectivity and, while the Watch mirrors a
        // workout, on the HealthKit session's data channel.
        let healthKitTransport = HealthKitTimerSyncTransport { mirroredWorkoutObserver.currentSession }
        mirroredWorkoutObserver.onRemoteData = { healthKitTransport.receive($0) }
        mirroredWorkoutObserver.onSessionConnected = { healthKitTransport.sessionDidConnect() }
        let timerSession = TimerSessionController(
            transport: CompositeTimerSyncTransport(transports: [
                WatchConnectivityTimerSyncTransport(),
                healthKitTransport
            ])
        )
        _timerSession = State(initialValue: timerSession)
        _workoutStarter = State(initialValue: PhoneWorkoutStarter(
            controller: timerSession,
            isWatchAppAvailable: { WatchConnectivityService.shared.isWatchAppAvailable },
            launchWatchApp: { config in
                let kind = TimerKind(rawValue: config.timerKindRaw) ?? .emom
                try await healthKitService.startWorkoutOnWatch(activityType: kind.healthKitActivityType)
            }
        ))

        // Receive the Watch's mirrored workout session. Set here rather than in a view's
        // onAppear, so a session mirrored during a background launch isn't missed.
        healthKitService.setupMirroringHandler { session in
            Logger.healthKit.info("Received mirrored workout session from Watch")
            mirroredWorkoutObserver.setSession(session)
        }

        // Activate WatchConnectivity *after* the coordinator's message handler is registered.
        WatchConnectivityService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(settings)
                    .environment(phoneMessageCoordinator)
                    .environment(timerSession)
                    .environment(workoutStarter)

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
        }
        .modelContainer(modelContainer)
    }
}
