//
//  WorkoutListFilterTests.swift
//  Kraftli TimersTests
//
//  The predicate behind `WorkoutListView`, run against a real (in-memory) store:
//  a `#Predicate` that compiles can still fail when SwiftData translates it.
//

import Foundation
import SwiftData
import Testing
@testable import Kraftli_Timers

@MainActor
struct WorkoutListFilterTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Burpees today and 10 days ago, squats today.
    private func makeContext() throws -> ModelContext {
        let container = try makeInMemoryContainer(for: WorkoutLog.self)
        let context = ModelContext(container)
        let tenDaysAgo = now.addingTimeInterval(-10 * 86_400)
        context.insert(WorkoutLog(date: now, exerciseName: "Burpees", timerKind: .amrap, durationSeconds: 600, roundsCompleted: 5))
        context.insert(WorkoutLog(date: tenDaysAgo, exerciseName: "Burpees", timerKind: .amrap, durationSeconds: 300, roundsCompleted: 3))
        context.insert(WorkoutLog(date: now, exerciseName: "Squats", timerKind: .amrap, durationSeconds: 900, roundsCompleted: 9))
        try context.save()
        return context
    }

    private func durations(_ context: ModelContext, exerciseName: String?, since start: Date?) throws -> Set<TimeInterval> {
        let descriptor = FetchDescriptor(predicate: WorkoutListView.filter(exerciseName: exerciseName, since: start))
        return Set(try context.fetch(descriptor).map(\.durationSeconds))
    }

    @Test func noFilter_returnsEverything() throws {
        #expect(try durations(makeContext(), exerciseName: nil, since: nil) == [600, 300, 900])
    }

    @Test func exercise_returnsOnlyItsWorkouts() throws {
        #expect(try durations(makeContext(), exerciseName: "Burpees", since: nil) == [600, 300])
    }

    @Test func exerciseAndStart_excludesEarlierWorkouts() throws {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)

        #expect(try durations(makeContext(), exerciseName: "Burpees", since: weekAgo) == [600])
    }

    @Test func start_appliesToAllExercises() throws {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)

        #expect(try durations(makeContext(), exerciseName: nil, since: weekAgo) == [600, 900])
    }
}
