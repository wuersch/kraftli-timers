//
//  WorkoutSessionManagerTests.swift
//  Kraftli Timers Watch AppTests
//
//  Regression tests for the session-identity guards in the HealthKit delegate
//  callbacks (GitHub issue #42). HK delivers delegate callbacks asynchronously,
//  so a callback for a torn-down session can land *after* cleanup has reset the
//  manager. Cleanup nils `session` first, so the guards filter exactly those
//  stale callbacks — these tests deliver callbacks while `session` is nil
//  (a fresh manager), which is the same situation as right after cleanup.
//

import Foundation
import HealthKit
import Testing
@testable import Kraftli_Timers_Watch_App

struct WorkoutSessionManagerTests {

    /// A session the manager has never seen — stands in for a torn-down session
    /// whose reference the manager already dropped.
    private func makeForeignSession() throws -> HKWorkoutSession {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .highIntensityIntervalTraining
        configuration.locationType = .indoor
        return try HKWorkoutSession(healthStore: HKHealthStore(), configuration: configuration)
    }

    // MARK: - didChangeTo (audit finding 1)

    /// The deterministic clobber behind the HR-blank field bug: after
    /// `endSession()` + `resetToIdle()`, HK's `.ended` callback used to land
    /// last and overwrite `.idle` — and every standalone-start gate requires
    /// `.idle`, so the next workout silently ran without an HKWorkoutSession.
    @Test @MainActor func staleEndedCallback_doesNotClobberIdleState() async throws {
        let manager = WorkoutSessionManager()
        let staleSession = try makeForeignSession()

        manager.workoutSession(staleSession, didChangeTo: .ended, from: .running, date: Date())
        await Self.drainMainQueue()

        #expect(manager.sessionState == .idle)
        #expect(manager.lastTransitionDate == nil)
    }

    @Test @MainActor func staleRunningCallback_doesNotResurrectSession() async throws {
        let manager = WorkoutSessionManager()
        let staleSession = try makeForeignSession()

        manager.workoutSession(staleSession, didChangeTo: .running, from: .notStarted, date: Date())
        await Self.drainMainQueue()

        #expect(manager.sessionState == .idle)
    }

    // MARK: - didFailWithError

    /// A stale failure callback must not run `cleanupSession()` — that would
    /// flip a freshly reset manager from `.idle` to `.ended`.
    @Test @MainActor func staleFailureCallback_doesNotRunCleanup() async throws {
        let manager = WorkoutSessionManager()
        let staleSession = try makeForeignSession()

        manager.workoutSession(
            staleSession,
            didFailWithError: HKError(.errorHealthDataUnavailable)
        )
        await Self.drainMainQueue()

        #expect(manager.sessionState == .idle)
    }

    // MARK: - Helpers

    /// Lets the main-actor Tasks queued by the delegate callbacks run before asserting.
    @MainActor
    private static func drainMainQueue() async {
        for _ in 0..<5 { await Task.yield() }
    }
}
