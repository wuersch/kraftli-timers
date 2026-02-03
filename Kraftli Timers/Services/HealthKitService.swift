//
//  HealthKitService.swift
//  Kraftli Timers
//
//  Manages HealthKit authorization and workout writing on iPhone.
//  Provides abstraction for testability via protocol.
//
//  ## How HealthKit Authorization Works
//  HealthKit uses a unique permission model: you can check if you've *requested*
//  authorization, but you can't check if the user *granted* read access (privacy).
//  Write access status is checkable. We request authorization lazily on first
//  workout completion, not on app launch.
//

#if os(iOS)
import Foundation
import HealthKit
import os

// MARK: - Protocol

/// Service for saving workouts to HealthKit and coordinating with Apple Watch.
///
/// Abstracted as a protocol to enable testing with mock implementations.
/// The app always attempts to save to HealthKit; there is no user-facing toggle.
protocol HealthKitService: Sendable {
    /// Whether HealthKit is available on this device.
    var isAvailable: Bool { get }

    /// Request authorization for the workout types we need.
    /// Safe to call multiple times; the system only shows the prompt once.
    func requestAuthorization() async throws

    /// Save a workout directly to HealthKit (iPhone-only scenario).
    ///
    /// Used for Scenario A when no Watch is involved. Saves duration only,
    /// no heart rate or calorie data (those require Watch sensors).
    ///
    /// - Parameters:
    ///   - activityType: The HealthKit activity type (e.g., `.highIntensityIntervalTraining`)
    ///   - start: Workout start time
    ///   - end: Workout end time
    ///   - metadata: Optional metadata including our workout ID for correlation
    /// - Returns: UUID of the saved HealthKit workout
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        metadata: [String: Any]?
    ) async throws -> UUID

    /// Start a workout on Apple Watch from iPhone (Scenario C).
    ///
    /// This calls `HKHealthStore.startWatchApp(toHandle:)` which causes watchOS
    /// to launch our Watch app and deliver the configuration to our `WKApplicationDelegate`.
    ///
    /// - Parameter activityType: The activity type for the workout
    func startWorkoutOnWatch(activityType: HKWorkoutActivityType) async throws

    /// Set up handler to receive mirrored workout sessions from Watch.
    ///
    /// When Watch starts a mirrored session (Scenarios C and D), iPhone receives
    /// the session via this handler. Call once during app setup.
    ///
    /// - Parameter handler: Called on the main actor when a mirrored session starts
    func setupMirroringHandler(_ handler: @escaping @MainActor (HKWorkoutSession) -> Void)
}

// MARK: - Default Implementation

/// Production implementation that interacts with the real HealthKit store.
final class DefaultHealthKitService: HealthKitService {
    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else {
            Logger.healthKit.info("HealthKit not available on this device")
            return
        }

        // Types we write
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        // Types we read (heart rate for future summary screens)
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        Logger.healthKit.info("HealthKit authorization requested")
    }

    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        metadata: [String: Any]?
    ) async throws -> UUID {
        guard isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        // Ensure we have authorization (system only shows prompt once)
        try await requestAuthorization()

        // Check write authorization for workouts
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        guard status == .sharingAuthorized else {
            Logger.healthKit.info("HealthKit write not authorized, skipping save")
            throw HealthKitServiceError.notAuthorized
        }

        // Build the workout
        // Note: No energy/distance for iPhone-only workouts. Only Watch provides
        // accurate calorie data via HKLiveWorkoutBuilder and Apple's algorithms.
        let workout = HKWorkout(
            activityType: activityType,
            start: start,
            end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata
        )

        try await healthStore.save(workout)
        Logger.healthKit.info("Saved workout to HealthKit: \(workout.uuid)")
        return workout.uuid
    }

    func startWorkoutOnWatch(activityType: HKWorkoutActivityType) async throws {
        guard isAvailable else {
            throw HealthKitServiceError.notAvailable
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor

        try await healthStore.startWatchApp(toHandle: configuration)
        Logger.healthKit.info("Sent workout configuration to Watch app")
    }

    func setupMirroringHandler(_ handler: @escaping @MainActor (HKWorkoutSession) -> Void) {
        healthStore.workoutSessionMirroringStartHandler = { session in
            Task { @MainActor in
                handler(session)
            }
        }
        Logger.healthKit.info("Mirroring start handler configured")
    }
}

// MARK: - Silent Implementation

/// No-op implementation for testing, previews, and when HealthKit is unavailable.
final class SilentHealthKitService: HealthKitService {
    var isAvailable: Bool { false }

    func requestAuthorization() async throws {}

    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        metadata: [String: Any]?
    ) async throws -> UUID {
        UUID()
    }

    func startWorkoutOnWatch(activityType: HKWorkoutActivityType) async throws {}

    func setupMirroringHandler(_ handler: @escaping @MainActor (HKWorkoutSession) -> Void) {}
}

// MARK: - Errors

enum HealthKitServiceError: Error, LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit write access not authorized"
        }
    }
}
#endif
