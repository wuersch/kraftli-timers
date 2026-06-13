//
//  WorkoutSessionManager.swift
//  Kraftli Timers Watch App
//
//  Manages HKWorkoutSession and HKLiveWorkoutBuilder lifecycle on Apple Watch.
//  Replaces WKExtendedRuntimeSession for keeping the app alive during workouts,
//  while also collecting heart rate and calorie data via Watch sensors.
//
//  ## How It Works
//  `HKWorkoutSession` keeps sensors active and the app running in the background.
//  `HKLiveWorkoutBuilder` automatically collects heart rate and energy samples
//  throughout the workout. When the session ends, the builder saves all collected
//  data to HealthKit as a single workout entry.
//

import Foundation
import HealthKit
import os

/// Manages the lifecycle of an HKWorkoutSession on Apple Watch.
///
/// This class handles:
/// - HealthKit authorization for workout types
/// - Starting, pausing, resuming, and ending workout sessions
/// - Collecting heart rate and calorie data via `HKLiveWorkoutBuilder`
/// - Saving completed workouts to HealthKit
/// - Enabling mirrored sessions for iPhone coordination
/// - Crash recovery for interrupted workouts
@Observable
@MainActor
final class WorkoutSessionManager: NSObject {
    // MARK: - Public State

    /// Current session state.
    private(set) var sessionState: SessionState = .idle

    /// The canonical `date` of the most recent session-state transition, as reported by
    /// HealthKit's delegate. This timestamp is identical on Watch and iPhone, so reconcile
    /// sites use it to re-anchor the timer (`pause(at:)` / `resume(at:)`) to a shared point
    /// instead of each device's local clock — eliminating cross-device pause/resume drift.
    private(set) var lastTransitionDate: Date?

    /// Most recent heart rate reading (beats per minute).
    private(set) var currentHeartRate: Double?

    /// Average heart rate during the workout (beats per minute).
    private(set) var averageHeartRate: Double?

    /// Maximum heart rate during the workout (beats per minute).
    private(set) var maxHeartRate: Double?

    /// Accumulated active energy burned (kilocalories).
    private(set) var activeCalories: Double?

    enum SessionState: Equatable {
        case idle
        case running
        case paused
        case ended
    }

    // MARK: - Private State

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Authorization

    /// Request authorization for workout-related HealthKit types.
    ///
    /// On Watch, we need write access for workouts, heart rate, and active energy.
    /// The system only shows the permission prompt once per type.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            Logger.healthKit.info("HealthKit not available on this device")
            return
        }

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        Logger.healthKit.info("Watch HealthKit authorization requested")
    }

    // MARK: - Session Lifecycle

    /// Start a new workout session with the given configuration.
    ///
    /// This activates Watch sensors (heart rate, accelerometer) and keeps the app
    /// running in the background. The `HKLiveWorkoutBuilder` automatically collects
    /// samples throughout the workout.
    ///
    /// - Parameter configuration: Workout configuration (activity type, location type)
    func startSession(configuration: HKWorkoutConfiguration) async throws {
        if sessionState != .idle {
            Logger.workoutSession.warning("Ending stale session (state: \(String(describing: self.sessionState))) before starting new one")
            _ = await endSession()
            resetToIdle()
        }

        // Reserve state immediately to prevent concurrent start attempts.
        // Even though @MainActor serializes Tasks, setting state before the
        // first suspension point ensures no interleaving.
        sessionState = .running

        do {
            // Ensure authorization
            try await requestAuthorization()

            // Create session
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            newSession.delegate = self
            self.session = newSession

            // Create builder for collecting metrics
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.delegate = self
            newBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            self.builder = newBuilder

            // Start session and builder
            let startDate = Date()
            newSession.startActivity(with: startDate)
            try await newBuilder.beginCollection(at: startDate)

            Logger.workoutSession.info("Workout session started")
        } catch {
            // Clean up on failure: end the session if it was started
            session?.end()
            session = nil
            builder = nil
            sessionState = .idle
            Logger.workoutSession.error("Failed to start session: \(error.localizedDescription)")
            throw error
        }
    }

    /// Pause the workout session.
    ///
    /// Called when the user pauses the timer. Pausing the session causes HealthKit
    /// to record the pause segment, so the workout duration in Apple Health
    /// accurately reflects active time only.
    func pause() {
        guard sessionState == .running, let session else { return }
        session.pause()
        // State update happens in delegate callback
        Logger.workoutSession.info("Workout session pause requested")
    }

    /// Resume the workout session.
    func resume() {
        guard sessionState == .paused, let session else { return }
        session.resume()
        // State update happens in delegate callback
        Logger.workoutSession.info("Workout session resume requested")
    }

    /// End the workout session and save to HealthKit.
    ///
    /// The builder is finalized *before* the session ends — Apple's API requires
    /// a live session for the builder to flush its data. On the happy path the
    /// sequence is: `endCollection` → `finishWorkout` → `session.end()`.
    ///
    /// **Simulator note:** The Watch simulator's `HKLiveWorkoutBuilder` may enter
    /// an internal error state (state 7) during the workout due to lack of real
    /// HealthKit infrastructure. When this happens, `endCollection` / `finishWorkout`
    /// log errors internally but our do/catch still handles it gracefully — the
    /// session is ended and cleanup runs via `defer`.
    ///
    /// - Returns: UUID of the saved HealthKit workout, or nil if save failed
    func endSession() async -> UUID? {
        guard let session, let builder else {
            Logger.workoutSession.warning("Cannot end session: no active session")
            // Clean up state even without session objects (e.g. stale state after crash)
            if sessionState != .idle { sessionState = .ended }
            return nil
        }

        defer { cleanupSession() }

        do {
            let endDate = Date()
            try await builder.endCollection(at: endDate)
            let workout = try await builder.finishWorkout()
            session.end()
            let workoutUUID = workout?.uuid
            Logger.workoutSession.info("Workout saved, UUID: \(workoutUUID?.uuidString ?? "nil")")
            return workoutUUID
        } catch {
            session.end()
            Logger.workoutSession.error("Failed to save workout: \(error.localizedDescription)")
            return nil
        }
    }

    /// Enable mirrored session so iPhone can track this workout.
    ///
    /// When mirroring is active, iPhone receives the session via
    /// `HKHealthStore.workoutSessionMirroringStartHandler` and can
    /// observe state changes (running, paused, ended).
    func startMirroring() async throws {
        try await session?.startMirroringToCompanionDevice()
        Logger.workoutSession.info("Started mirroring to companion device")
    }

    /// Recover an active workout session after app crash or restart.
    ///
    /// watchOS preserves active `HKWorkoutSession` across app launches.
    /// If the app was killed during a workout, this method recovers the session
    /// and **finalizes** it — the timer model and UI state were lost in the crash so
    /// there's nothing to resume, but the HR/energy collected before the kill is real
    /// data the user earned, so we save it to HealthKit rather than discard it (issue #49).
    ///
    /// We finalize with a recovery-time end date (mirroring `endSession()`), accepting that
    /// an unusually long gap before relaunch could inflate the duration — fine for the common
    /// prompt auto-relaunch path. The app metadata (exercise name, kind, correlation ID) was
    /// lost in the crash, so we deliberately don't write a SwiftData `WorkoutLog` or notify the
    /// iPhone — landing the workout in Apple Health is the win. See ADR-002.
    func recoverActiveSession() async throws {
        Logger.workoutSession.info("Attempting to recover active session")

        do {
            guard let recoveredSession = try await healthStore.recoverActiveWorkoutSession() else {
                Logger.workoutSession.debug("No active session to recover")
                return
            }
            Logger.workoutSession.info("Recovered orphaned workout session, finalizing it")
            recoveredSession.delegate = self
            self.session = recoveredSession
            let builder = recoveredSession.associatedWorkoutBuilder()
            self.builder = builder

            do {
                try await builder.endCollection(at: Date())
                let workout = try await builder.finishWorkout()
                recoveredSession.end()
                Logger.workoutSession.info("Recovered workout finalized, UUID: \(workout?.uuid.uuidString ?? "nil")")
            } catch {
                recoveredSession.end()
                Logger.workoutSession.error("Failed to finalize recovered workout: \(error.localizedDescription)")
            }

            // Land at .idle (not cleanupSession()'s .ended) so the next standalone start gate
            // passes; niling session first means the trailing .ended delegate callback is
            // dropped by the identity guard rather than clobbering this state.
            session = nil
            self.builder = nil
            sessionState = .idle
        } catch {
            // Recovery failed — log and continue
            Logger.workoutSession.debug("Failed to recover active session: \(error.localizedDescription)")
        }
    }

    /// Cleans up any orphaned HKWorkoutSession left by a previous app launch.
    ///
    /// Called at app startup when our session reference is nil and state is idle.
    /// If the system has an active session from a previous crash or force-quit,
    /// we recover and end it so it doesn't block new sessions.
    func cleanupOrphanedSessionIfNeeded() async {
        // Only run when we have no session reference (fresh launch)
        guard session == nil, sessionState == .idle else { return }

        do {
            try await recoverActiveSession()
        } catch {
            // No orphan found — this is the happy path
        }
    }

    /// Reset manager to idle state (for cleanup after workout is fully processed).
    func resetToIdle() {
        Logger.workoutSession.info("resetToIdle: \(String(describing: self.sessionState)) → .idle")
        sessionState = .idle
    }

    // MARK: - Private Helpers

    /// Resets all session state to a clean slate.
    ///
    /// Called from `defer` in `endSession()` to guarantee cleanup runs even
    /// when `HKLiveWorkoutBuilder` throws, and from `didFailWithError` to
    /// prevent subsequent `endSession()` calls from operating on a broken builder.
    private func cleanupSession() {
        session = nil
        builder = nil
        sessionState = .ended
        currentHeartRate = nil
        averageHeartRate = nil
        maxHeartRate = nil
        activeCalories = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            // Ignore callbacks from a session that is no longer ours. Cleanup and
            // recovery nil out `session` before this Task runs, so a late `.ended`
            // transition for a torn-down session can't clobber freshly reset state
            // (it would stick sessionState at .ended and block every standalone
            // start gate that requires .idle — HR/kcal would show "--" forever).
            guard workoutSession === self.session else {
                Logger.workoutSession.info("Ignoring state change \(String(describing: fromState)) → \(String(describing: toState)) from stale session")
                return
            }
            // Set the canonical transition date BEFORE sessionState so the view's
            // onChange(of: sessionState) observer reads the matching date.
            lastTransitionDate = date
            switch toState {
            case .running:
                sessionState = .running
            case .paused:
                sessionState = .paused
            case .ended:
                sessionState = .ended
            default:
                break
            }
            Logger.workoutSession.info("Session state changed: \(String(describing: fromState)) → \(String(describing: toState))")
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            // A failure from an already-replaced session must not tear down the
            // current one's state.
            guard workoutSession === self.session else {
                Logger.workoutSession.info("Ignoring failure from stale session: \(error.localizedDescription)")
                return
            }
            Logger.workoutSession.error("Workout session failed: \(error.localizedDescription)")
            cleanupSession()
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                Logger.workoutSession.error("Workout session disconnected with error: \(error.localizedDescription)")
            } else {
                Logger.workoutSession.info("Workout session disconnected from remote device")
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Workout events (pause, resume, etc.) are automatically handled
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            // A late sample from a torn-down builder must not re-populate the
            // metrics that cleanupSession() just cleared.
            guard workoutBuilder === self.builder else { return }
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }

                // Get most recent statistic for this type
                guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    currentHeartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
                    averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit)
                    maxHeartRate = statistics.maximumQuantity()?.doubleValue(for: heartRateUnit)

                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())

                default:
                    break
                }
            }
        }
    }
}
