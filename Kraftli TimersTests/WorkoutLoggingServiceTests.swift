//
//  WorkoutLoggingServiceTests.swift
//  Kraftli TimersTests
//

import Foundation
import SwiftData
import Testing
@testable import Kraftli_Timers

struct WorkoutLoggingServiceTests {

    // MARK: - SilentWorkoutLoggingService Tests

    @Test func silentService_logWorkout_doesNotThrow() {
        let service = SilentWorkoutLoggingService()

        // Should complete without error
        service.logWorkout(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100,
            roundsCompleted: nil
        )

        // If we get here, the test passes (no exceptions thrown)
        #expect(true)
    }

    @Test func silentService_logWorkout_amrap_doesNotThrow() {
        let service = SilentWorkoutLoggingService()

        service.logWorkout(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 600,
            repsCompleted: nil,
            roundsCompleted: 5
        )

        #expect(true)
    }

    // MARK: - DefaultWorkoutLoggingService Tests (with in-memory store)

    @Test @MainActor func defaultService_logWorkout_emom_persistsToContext() throws {
        // Create in-memory model context
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let service = DefaultWorkoutLoggingService(modelContext: context)

        // Log a workout
        service.logWorkout(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100,
            roundsCompleted: nil
        )

        // Fetch and verify
        let descriptor = FetchDescriptor<WorkoutLog>()
        let workouts = try context.fetch(descriptor)

        #expect(workouts.count == 1)
        #expect(workouts.first?.exerciseName == "Burpees")
        #expect(workouts.first?.timerKind == .emom)
        #expect(workouts.first?.durationSeconds == 1200)
        #expect(workouts.first?.repsCompleted == 100)
    }

    @Test @MainActor func defaultService_logWorkout_amrap_persistsToContext() throws {
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let service = DefaultWorkoutLoggingService(modelContext: context)

        service.logWorkout(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 900,
            repsCompleted: nil,
            roundsCompleted: 8
        )

        let descriptor = FetchDescriptor<WorkoutLog>()
        let workouts = try context.fetch(descriptor)

        #expect(workouts.count == 1)
        #expect(workouts.first?.exerciseName == "Pull-ups")
        #expect(workouts.first?.timerKind == .amrap)
        #expect(workouts.first?.roundsCompleted == 8)
    }

    @Test @MainActor func defaultService_logWorkout_withHealthKitUUID_persistsUUID() throws {
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let service = DefaultWorkoutLoggingService(modelContext: context)
        let hkUUID = UUID()

        service.logWorkout(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100,
            roundsCompleted: nil,
            healthKitWorkoutUUID: hkUUID
        )

        let descriptor = FetchDescriptor<WorkoutLog>()
        let workouts = try context.fetch(descriptor)

        #expect(workouts.count == 1)
        #expect(workouts.first?.healthKitWorkoutUUID == hkUUID)
    }

    @Test @MainActor func defaultService_logWorkout_withoutHealthKitUUID_persistsNil() throws {
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let service = DefaultWorkoutLoggingService(modelContext: context)

        service.logWorkout(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 600,
            repsCompleted: nil,
            roundsCompleted: 5
        )

        let descriptor = FetchDescriptor<WorkoutLog>()
        let workouts = try context.fetch(descriptor)

        #expect(workouts.count == 1)
        #expect(workouts.first?.healthKitWorkoutUUID == nil)
    }

    @Test @MainActor func defaultService_logMultipleWorkouts_persistsAll() throws {
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let service = DefaultWorkoutLoggingService(modelContext: context)

        // Log multiple workouts
        service.logWorkout(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100,
            roundsCompleted: nil
        )

        service.logWorkout(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 600,
            repsCompleted: nil,
            roundsCompleted: 5
        )

        let descriptor = FetchDescriptor<WorkoutLog>()
        let workouts = try context.fetch(descriptor)

        #expect(workouts.count == 2)
    }

    @Test @MainActor func defaultService_logWorkout_setsCurrentDate() throws {
        let schema = Schema([WorkoutLog.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let beforeLog = Date()

        let service = DefaultWorkoutLoggingService(modelContext: context)
        service.logWorkout(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100,
            roundsCompleted: nil
        )

        let afterLog = Date()

        let descriptor = FetchDescriptor<WorkoutLog>()
        let workouts = try context.fetch(descriptor)

        #expect(workouts.first?.date != nil)
        #expect(workouts.first!.date >= beforeLog)
        #expect(workouts.first!.date <= afterLog)
    }
}
