//
//  WatchWorkoutStarterTests.swift
//  Kraftli TimersTests
//
//  The Watch's side of the start handshake (ADR-006 §4): owning a requested
//  workout, yielding to the iPhone, early intents, stale requests and the watchdog.
//  `WatchWorkoutStarter` runs on the Watch; it is tested here, against the
//  iPhone's controller, because both share the same fake link.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct WatchWorkoutStarterTests {

    // MARK: - Fixtures

    private struct SessionFailed: Error {}

    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)
        func advance(_ seconds: TimeInterval) { now += seconds }
    }

    /// Stands in for the Watch's HealthKit session and keep-alive.
    @MainActor
    private final class FakeHealth {
        var starts = 0
        var discards = 0
        var keepAliveStarts = 0
        var keepAliveEnds = 0
        var fails = false

        func start() throws {
            starts += 1
            if fails { throw SessionFailed() }
        }
    }

    /// iPhone and Watch controllers over a `FakeLink`, with the Watch's starter.
    @MainActor
    private struct Setup {
        let clock = Clock()
        let link = FakeLink()
        let health = FakeHealth()
        let phone: TimerSessionController
        let watch: TimerSessionController
        let starter: WatchWorkoutStarter
        let config = TimerConfig(
            timerKindRaw: TimerKind.emom.rawValue,
            totalDuration: 600,
            intervalCount: 10,
            exerciseName: "Burpees"
        )

        init() {
            let clock = self.clock
            let health = self.health
            phone = TimerSessionController(
                transport: CompositeTimerSyncTransport(transports: [link.phoneEnd]),
                now: { clock.now },
                schedulesCompletion: false
            )
            let watchTransport = CompositeTimerSyncTransport(transports: [link.watchEnd])
            watch = TimerSessionController(transport: watchTransport, now: { clock.now }, schedulesCompletion: false)
            starter = WatchWorkoutStarter(
                controller: watch,
                transport: watchTransport,
                startHealthSession: { _ in try health.start() },
                discardHealthSession: { health.discards += 1 },
                startKeepAlive: { health.keepAliveStarts += 1 },
                endKeepAlive: { health.keepAliveEnds += 1 },
                now: { clock.now },
                schedulesWatchdog: false
            )
        }

        /// The iPhone asks the Watch to start a workout (`PhoneWorkoutStarter`'s request).
        @discardableResult
        func phoneRequestsStart(at date: Date? = nil) -> StartRequest {
            let request = StartRequest(workoutID: UUID(), config: config, requestedAt: date ?? clock.now)
            phone.requestStart(request)
            return request
        }

        /// The iPhone's handshake timed out: it owns the workout itself.
        func phoneTakesOver(_ request: StartRequest) {
            phone.startAsOwner(TimerState(workoutID: request.workoutID, owner: .phone, config: config, now: clock.now))
        }

        /// Lets the HealthKit session start finish and the starter react to it.
        func sessionStarts() async {
            await starter.ownershipTask?.value
        }
    }

    // MARK: - Owning a requested workout

    @Test func request_showsStarting_thenWatchOwnsOnceSessionRuns() async {
        let setup = Setup()
        let request = setup.phoneRequestsStart()

        #expect(setup.watch.isAwaitingOwner && setup.watch.workoutID == request.workoutID)
        #expect(setup.starter.requestedWorkout == request)  // the UI presents "Starting…"

        await setup.sessionStarts()

        #expect(setup.watch.role == .owner)
        #expect(setup.watch.renderedState?.owner == .watch)
        #expect(setup.watch.renderedState?.startDate == setup.clock.now.addingTimeInterval(TimerState.countdownDuration))
        #expect(setup.phone.renderedState == setup.watch.renderedState)  // the iPhone follows
        #expect(setup.health.starts == 1 && setup.health.discards == 0)
    }

    @Test func requestAndWatchAppLaunch_shareOneSessionStart() async {
        let setup = Setup()
        var launchStarts = 0

        setup.phoneRequestsStart()
        setup.starter.watchAppLaunched { launchStarts += 1 }  // handle(_ workoutConfiguration:)
        await setup.sessionStarts()

        #expect(setup.health.starts + launchStarts == 1)
        #expect(setup.watch.role == .owner)
    }

    @Test func staleRequest_isIgnored() {
        let setup = Setup()

        setup.phoneRequestsStart(at: setup.clock.now.addingTimeInterval(-(WatchWorkoutStarter.maxRequestAge + 1)))

        #expect(setup.watch.role == nil)
        #expect(setup.starter.requestedWorkout == nil)
        #expect(setup.health.starts == 0)
    }

    @Test func failedSession_watchKeepsWaitingForThePhone() async {
        let setup = Setup()
        setup.health.fails = true
        let request = setup.phoneRequestsStart()

        await setup.sessionStarts()
        #expect(setup.watch.isAwaitingOwner)

        setup.phoneTakesOver(request)  // the iPhone's 5 s timeout
        #expect(setup.watch.role == .viewer)
        #expect(setup.watch.renderedState?.owner == .phone)
    }

    // MARK: - Yield

    @Test func phoneTakesOverBeforeSessionRuns_watchYieldsAndDiscardsSession() async {
        let setup = Setup()
        let request = setup.phoneRequestsStart()

        setup.phoneTakesOver(request)
        await setup.sessionStarts()

        #expect(setup.watch.role == .viewer)
        #expect(setup.watch.renderedState?.owner == .phone)
        #expect(setup.health.discards >= 1)  // no second Health workout
        #expect(setup.health.keepAliveStarts == 1)
        #expect(setup.phone.role == .owner)
    }

    @Test func crossedHandshake_resolvesToThePhone() async {
        let setup = Setup()
        let request = setup.phoneRequestsStart()
        setup.link.isConnected = false

        await setup.sessionStarts()         // the Watch owns it, but the iPhone doesn't hear back…
        setup.phoneTakesOver(request)       // …so the iPhone times out and owns it too
        #expect(setup.watch.role == .owner && setup.phone.role == .owner)

        setup.link.isConnected = true       // both revision-1 snapshots cross

        #expect(setup.phone.role == .owner)
        #expect(setup.phone.renderedState?.owner == .phone)
        #expect(setup.watch.role == .viewer)
        #expect(setup.watch.renderedState?.owner == .phone)
        #expect(setup.health.discards == 1)
    }

    // MARK: - Early intents

    @Test func stopSentWhileStarting_endsTheWorkoutRightAfterItStarts() async {
        let setup = Setup()
        setup.phoneRequestsStart()

        setup.phone.stop()   // the iPhone user swiped down during "Starting on Watch…"
        setup.phone.end()
        await setup.sessionStarts()

        guard case .stopped = setup.watch.confirmedState?.finish else {
            Issue.record("Expected the early stop to end the workout")
            return
        }
    }

    // MARK: - Watchdog and lifecycle

    @Test func watchdog_closesAWorkoutNobodyConfirmed() async {
        let setup = Setup()
        setup.health.fails = true
        setup.phoneRequestsStart()
        await setup.sessionStarts()

        setup.starter.watchdogFired()

        #expect(setup.watch.role == nil && setup.watch.workoutID == nil)
    }

    @Test func watchdog_leavesAnOwnedWorkoutAlone() async {
        let setup = Setup()
        setup.phoneRequestsStart()
        await setup.sessionStarts()

        setup.starter.watchdogFired()

        #expect(setup.watch.role == .owner)
    }

    @Test func watchStartedWorkout_isOwnedImmediately() async {
        let setup = Setup()
        let workoutID = UUID()

        setup.starter.startOnWatch(workoutID: workoutID, config: setup.config)

        #expect(setup.watch.role == .owner && setup.watch.workoutID == workoutID)
        #expect(setup.watch.renderedState?.owner == .watch)
    }

    @Test func workoutEnded_endsTheSessionAndKeepAlive() async {
        let setup = Setup()
        let request = setup.phoneRequestsStart()
        setup.phoneTakesOver(request)
        await setup.sessionStarts()

        setup.starter.workoutEnded()

        #expect(setup.watch.role == nil)
        #expect(setup.health.keepAliveEnds == 1)
    }
}
