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

    init() {
        let schema = Schema([
            Exercise.self,
            TimerPreset.self,
            WorkoutLog.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container

            // Seed default data on first launch (synchronous to avoid race with @Query)
            Self.seedDefaultDataIfNeeded(in: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Data Seeding

    private static func seedDefaultDataIfNeeded(in context: ModelContext) {
        // Check if we already have presets
        let presetDescriptor = FetchDescriptor<TimerPreset>()
        let existingPresets = (try? context.fetchCount(presetDescriptor)) ?? 0

        guard existingPresets == 0 else { return }

        // Load and create exercises from JSON
        let exerciseDataList = ExerciseLoader.loadBundled()
        var exercisesByName: [String: Exercise] = [:]

        for data in exerciseDataList {
            let exercise = Exercise(from: data)
            context.insert(exercise)
            exercisesByName[data.name] = exercise
        }

        // Create default presets
        let defaults: [(kind: TimerKind, minutes: Int, reps: Int?, exerciseName: String)] = [
            (.emom, 20, 100, "6-Count Burpees"),
            (.emom, 20, 35, "Navy Seal Burpees"),
            (.amrap, 20, nil, "Pull-ups"),
            (.emom, 1, 6, "Push-ups")
        ]

        for (index, preset) in defaults.enumerated() {
            let timerPreset = TimerPreset(
                kind: preset.kind,
                durationInterval: TimeInterval(preset.minutes * 60),
                targetReps: preset.reps,
                sortOrder: index,
                exercise: exercisesByName[preset.exerciseName]
            )
            context.insert(timerPreset)
        }

        try? context.save()
    }
}
