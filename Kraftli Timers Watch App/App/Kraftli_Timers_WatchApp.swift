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
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(messageCoordinator)
        }
        .modelContainer(modelContainer)
    }
}
