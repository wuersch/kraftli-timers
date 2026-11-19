//
//  WorkoutRecorderTests.swift
//  Kraftli TimersTests
//
//  The recorder writes the workout log and decides who saves the Health workout
//  (ADR-006 §1): the iPhone for a workout it owned, the Watch for one it owned.
//

import Foundation
import HealthKit
import SwiftData
import Testing
@testable import Kraftli_Timers

@MainActor
struct WorkoutRecorderTests {

    /// Records what the recorder asks HealthKit to save.
    private final class FakeHealthKitService: HealthKitService, @unchecked Sendable {
        var isAvailable = true
        var failsToSave = false
        let savedUUID = UUID()
        private(set) var saves: [(start: Date, end: Date, pauses: [DateInterval], metadata: [String: Any]?)] = []

        func requestAuthorization() async throws {}

        func saveWorkout(
            activityType: HKWorkoutActivityType,
            start: Date,
            end: Date,
            pauses: [DateInterval],
            metadata: [String: Any]?
        ) async throws -> UUID {
            if failsToSave { throw HealthKitServiceError.saveFailed }
            saves.append((start, end, pauses, metadata))
            return savedUUID
        }

        func startWorkoutOnWatch(activityType: HKWorkoutActivityType) async throws {}
        func setupMirroringHandler(_ handler: @escaping @MainActor (HKWorkoutSession) -> Void) {}
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeRecorder(
        _ healthKit: FakeHealthKitService
    ) throws -> (recorder: DefaultWorkoutRecorder, context: ModelContext) {
        let container = try makeInMemoryContainer(for: WorkoutLog.self)
        let context = ModelContext(container)
        let now = now
        return (DefaultWorkoutRecorder(modelContext: context, healthKit: healthKit, now: { now }), context)
    }

    private func completion(ownedByWatch: Bool, workoutID: UUID = UUID()) -> WorkoutCompletionData {
        var data = WorkoutCompletionData(durationSeconds: 600, repsCompleted: nil, roundsCompleted: 7)
        data.ownedByWatch = ownedByWatch
        data.correlationID = workoutID
        return data
    }

    private func logs(in context: ModelContext) throws -> [WorkoutLog] {
        try context.fetch(FetchDescriptor<WorkoutLog>())
    }

    @Test func phoneOwned_savesLogWithWorkoutIDAndHealthUUID() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, context) = try makeRecorder(healthKit)
        let workoutID = UUID()

        await recorder.record(
            completion(ownedByWatch: false, workoutID: workoutID),
            exerciseName: "Burpees",
            timerKind: .amrap
        ).value

        let log = try #require(try logs(in: context).first)
        #expect(log.id == workoutID)
        #expect(log.exerciseName == "Burpees")
        #expect(log.roundsCompleted == 7)
        #expect(log.healthKitWorkoutUUID == healthKit.savedUUID)
    }

    @Test func phoneOwned_healthWorkoutEndsNowAndSpansTheDuration() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, _) = try makeRecorder(healthKit)
        let workoutID = UUID()

        await recorder.record(
            completion(ownedByWatch: false, workoutID: workoutID),
            exerciseName: "Burpees",
            timerKind: .amrap
        ).value

        let save = try #require(healthKit.saves.first)
        #expect(save.end == now)
        #expect(save.start == now.addingTimeInterval(-600))
        #expect(save.metadata?[HKMetadataKeyExternalUUID] as? String == workoutID.uuidString)
        #expect(save.metadata?[DefaultWorkoutRecorder.MetadataKey.timerKind] as? String == "AMRAP")
        #expect(save.metadata?[DefaultWorkoutRecorder.MetadataKey.exercise] as? String == "Burpees")
    }

    /// The Watch saves the Health workout of a workout it owned; a second one from the
    /// iPhone would be a duplicate.
    @Test func watchOwned_savesLogButNoHealthWorkout() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, context) = try makeRecorder(healthKit)

        await recorder.record(completion(ownedByWatch: true), exerciseName: "Burpees", timerKind: .amrap).value

        let log = try #require(try logs(in: context).first)
        #expect(log.healthKitWorkoutUUID == nil)
        #expect(healthKit.saves.isEmpty)
    }

    @Test func healthKitFailure_keepsTheLog() async throws {
        let healthKit = FakeHealthKitService()
        healthKit.failsToSave = true
        let (recorder, context) = try makeRecorder(healthKit)

        await recorder.record(completion(ownedByWatch: false), exerciseName: "Burpees", timerKind: .amrap).value

        let log = try #require(try logs(in: context).first)
        #expect(log.healthKitWorkoutUUID == nil)
    }

    @Test func healthKitUnavailable_keepsTheLog() async throws {
        let healthKit = FakeHealthKitService()
        healthKit.isAvailable = false
        let (recorder, context) = try makeRecorder(healthKit)

        await recorder.record(completion(ownedByWatch: false), exerciseName: "Burpees", timerKind: .amrap).value

        #expect(try logs(in: context).count == 1)
        #expect(healthKit.saves.isEmpty)
    }

    /// A workout stopped early is recorded with its active time and marked (UC-0005 1a).
    /// The iPhone's Health workout then covers that active time.
    @Test func stoppedEarly_marksTheLog_andSavesTheActiveTimeToHealth() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, context) = try makeRecorder(healthKit)
        var stopped = WorkoutCompletionData(durationSeconds: 163, repsCompleted: nil, roundsCompleted: 5)
        stopped.stoppedEarly = true

        await recorder.record(stopped, exerciseName: "Burpees", timerKind: .amrap).value

        let log = try #require(try logs(in: context).first)
        #expect(log.stoppedEarly)
        #expect(log.durationSeconds == 163)
        #expect(log.roundsCompleted == 5)
        let save = try #require(healthKit.saves.first)
        #expect(save.end.timeIntervalSince(save.start) == 163)
    }

    @Test func completedWorkout_isNotMarkedAsStoppedEarly() async throws {
        let (recorder, context) = try makeRecorder(FakeHealthKitService())

        await recorder.record(completion(ownedByWatch: false), exerciseName: "Burpees", timerKind: .amrap).value

        #expect(try #require(try logs(in: context).first).stoppedEarly == false)
    }

    // MARK: - Sessions (UC-0005 extension 3d)

    private func stepOfASession(_ runID: UUID) -> WorkoutCompletionData {
        var data = completion(ownedByWatch: false)
        data.sessionName = "Full Body"
        data.sessionRunID = runID
        return data
    }

    @Test func stepOfASession_isLoggedWithItsSession_butGetsNoHealthWorkoutOfItsOwn() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, context) = try makeRecorder(healthKit)
        let runID = UUID()

        await recorder.record(stepOfASession(runID), exerciseName: "Burpees", timerKind: .amrap).value

        let log = try #require(try logs(in: context).first)
        #expect(log.sessionName == "Full Body")
        #expect(log.sessionRunID == runID)
        #expect(log.healthKitWorkoutUUID == nil)
        #expect(healthKit.saves.isEmpty)
    }

    @Test func session_getsOneHealthWorkout_withTheWaitsAsPauses_linkedToEveryStep() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, context) = try makeRecorder(healthKit)
        let runID = UUID()
        await recorder.record(stepOfASession(runID), exerciseName: "Burpees", timerKind: .amrap).value
        await recorder.record(stepOfASession(runID), exerciseName: "Squats", timerKind: .amrap).value
        // A workout that has nothing to do with the session.
        await recorder.record(completion(ownedByWatch: true), exerciseName: "Other", timerKind: .amrap).value

        await recorder.recordSession(runID: runID, name: "Full Body", activeIntervals: [
            DateInterval(start: now, duration: 600),
            DateInterval(start: now.addingTimeInterval(900), duration: 600)
        ]).value

        let save = try #require(healthKit.saves.first)
        #expect(healthKit.saves.count == 1)
        #expect(save.start == now)
        #expect(save.end == now.addingTimeInterval(1500))
        #expect(save.pauses == [DateInterval(start: now.addingTimeInterval(600), duration: 300)])
        #expect(save.metadata?[HKMetadataKeyExternalUUID] as? String == runID.uuidString)

        let all = try logs(in: context)
        #expect(all.filter { $0.sessionRunID == runID }.allSatisfy { $0.healthKitWorkoutUUID == healthKit.savedUUID })
        #expect(all.first { $0.exerciseName == "Other" }?.healthKitWorkoutUUID == nil)
    }

    @Test func sessionWithoutARecordedStep_getsNoHealthWorkout() async throws {
        let healthKit = FakeHealthKitService()
        let (recorder, _) = try makeRecorder(healthKit)

        await recorder.recordSession(
            runID: UUID(), name: "Full Body", activeIntervals: [DateInterval(start: now, duration: 30)]
        ).value

        #expect(healthKit.saves.isEmpty)
    }
}
