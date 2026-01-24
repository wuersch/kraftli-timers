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
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
