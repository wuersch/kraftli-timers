//
//  WorkoutRecorder.swift
//  Kraftli Timers
//
//  Records a completed workout: the workout log, and the Health workout when the
//  iPhone owned the timer.
//

#if os(iOS)
import Foundation
import HealthKit
import SwiftData
import SwiftUI
import os

// MARK: - Protocol

/// Records a workout the iPhone started, once it has completed.
///
/// The iPhone always writes the `WorkoutLog` of a workout it started. The Health save
/// follows the workout's owner (ADR-006 §1):
/// - **iPhone owner:** save to HealthKit on the iPhone, then store its UUID in the log.
/// - **Watch owner:** skip the iPhone's HealthKit save (the Watch saves it). The log is
///   written without a UUID; the Watch sends its UUID via `WorkoutSessionEndedMessage`.
protocol WorkoutRecorder {
    /// Records the workout. The log is written before this returns; the Health save
    /// runs in the returned task. If HealthKit fails, the log stays without a UUID.
    @discardableResult
    func record(
        _ completion: WorkoutCompletionData,
        exerciseName: String,
        timerKind: TimerKind
    ) -> Task<Void, Never>
}

// MARK: - Default Implementation

final class DefaultWorkoutRecorder: WorkoutRecorder {
    /// HealthKit metadata keys identifying the app's workouts.
    enum MetadataKey {
        static let timerKind = "com.kraftli.timer.kind"
        static let exercise = "com.kraftli.timer.exercise"
    }

    private let modelContext: ModelContext
    private let loggingService: WorkoutLoggingService
    private let healthKit: any HealthKitService
    /// Wall-clock source. Injectable so tests can pin the Health workout's time span.
    private let now: () -> Date

    init(
        modelContext: ModelContext,
        healthKit: any HealthKitService,
        now: @escaping () -> Date = { Date() }
    ) {
        self.modelContext = modelContext
        self.loggingService = DefaultWorkoutLoggingService(modelContext: modelContext)
        self.healthKit = healthKit
        self.now = now
    }

    @discardableResult
    func record(
        _ completion: WorkoutCompletionData,
        exerciseName: String,
        timerKind: TimerKind
    ) -> Task<Void, Never> {
        // 1. Save to SwiftData first (always, regardless of HealthKit)
        let workoutLog = loggingService.logWorkout(
            exerciseName: exerciseName,
            timerKind: timerKind,
            durationSeconds: completion.durationSeconds,
            repsCompleted: completion.repsCompleted,
            roundsCompleted: completion.roundsCompleted,
            healthKitWorkoutUUID: nil,
            // The workout's ID, so the Watch can match its HealthKit UUID to this exact
            // log (instead of a "latest" heuristic).
            id: completion.correlationID
        )

        // 2. Save to HealthKit (if the iPhone is handling it)
        guard !completion.ownedByWatch else {
            // The Watch owned the workout and saves it to Health — skip ours to avoid
            // duplicates. Its UUID arrives via the workoutSessionEnded message.
            Logger.healthKit.info("Watch owned the workout, skipping iPhone HealthKit save")
            return Task {}
        }
        guard healthKit.isAvailable else { return Task {} }

        // iPhone-only: save duration (no calories — those require Watch sensors)
        let endDate = now()
        let startDate = endDate.addingTimeInterval(-completion.durationSeconds)
        return Task {
            do {
                let healthKitUUID = try await healthKit.saveWorkout(
                    activityType: timerKind.healthKitActivityType,
                    start: startDate,
                    end: endDate,
                    metadata: [
                        HKMetadataKeyExternalUUID: workoutLog.id.uuidString,
                        MetadataKey.timerKind: timerKind.rawValue,
                        MetadataKey.exercise: exerciseName
                    ]
                )
                // Update the SwiftData record with the HealthKit UUID for correlation
                workoutLog.healthKitWorkoutUUID = healthKitUUID
                try modelContext.save()
            } catch {
                Logger.healthKit.error("Failed to save workout to HealthKit: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Silent Implementation

/// Records nothing. For previews and tests.
final class SilentWorkoutRecorder: WorkoutRecorder {
    @discardableResult
    func record(
        _ completion: WorkoutCompletionData,
        exerciseName: String,
        timerKind: TimerKind
    ) -> Task<Void, Never> {
        Task {}
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// The app's workout recorder.
    ///
    /// `@Entry` declares a custom environment value with its default in one line. A
    /// service that is a protocol (rather than one `@Observable` class) is injected
    /// this way: `.environment(\.workoutRecorder, recorder)` at the root, and
    /// `@Environment(\.workoutRecorder)` where it is used. The silent default means
    /// previews and tests never write logs or touch HealthKit by accident.
    @Entry var workoutRecorder: any WorkoutRecorder = SilentWorkoutRecorder()
}
#endif
