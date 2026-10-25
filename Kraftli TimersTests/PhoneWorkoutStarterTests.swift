//
//  PhoneWorkoutStarterTests.swift
//  Kraftli TimersTests
//
//  The iPhone's start handshake (ADR-006 §4): Watch owner if it answers in time,
//  iPhone owner otherwise.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct PhoneWorkoutStarterTests {

    // MARK: - Fixtures

    private struct LaunchFailed: Error {}

    /// Records Watch launches and optionally fails them.
    @MainActor
    private final class Launcher {
        var configs: [TimerConfig] = []
        var fails = false

        func launch(_ config: TimerConfig) throws {
            configs.append(config)
            if fails { throw LaunchFailed() }
        }
    }

    /// The iPhone's controller and starter, linked to a Watch-side controller.
    @MainActor
    private struct Setup {
        let link = FakeLink()
        let launcher = Launcher()
        let phone: TimerSessionController
        let watch: TimerSessionController
        let watchTransport: CompositeTimerSyncTransport
        let starter: PhoneWorkoutStarter
        let workoutID = UUID()
        let config = TimerConfig(
            timerKindRaw: TimerKind.emom.rawValue,
            totalDuration: 600,
            intervalCount: 10,
            exerciseName: "Burpees"
        )

        init(isWatchAppAvailable: Bool = true) {
            phone = TimerSessionController(
                transport: CompositeTimerSyncTransport(transports: [link.phoneEnd]),
                schedulesCompletion: false
            )
            watchTransport = CompositeTimerSyncTransport(transports: [link.watchEnd])
            watch = TimerSessionController(transport: watchTransport, schedulesCompletion: false)
            let launcher = self.launcher
            starter = PhoneWorkoutStarter(
                controller: phone,
                isWatchAppAvailable: { isWatchAppAvailable },
                launchWatchApp: { try await launcher.launch($0) },
                schedulesTimeout: false
            )
        }

        func start() {
            starter.start(workoutID: workoutID, config: config)
        }

        /// The Watch answers the request, as it will in slice 5B.
        func watchConfirms() {
            watch.startAsOwner(TimerState(workoutID: workoutID, owner: .watch, config: config, now: Date()))
        }
    }

    // MARK: - No Watch

    @Test func noWatchApp_startsOnPhoneImmediately() {
        let setup = Setup(isWatchAppAvailable: false)
        var requests: [StartRequest] = []
        setup.watchTransport.onStartRequest = { requests.append($0) }

        setup.start()

        #expect(setup.phone.role == .owner)
        #expect(setup.phone.renderedState?.owner == .phone)
        #expect(setup.phone.workoutID == setup.workoutID)
        #expect(requests.isEmpty && setup.launcher.configs.isEmpty)
        #expect(setup.starter.lastFallbackDate == nil)  // nothing failed: no notice
    }

    // MARK: - Watch available

    @Test func watchAvailable_requestsStart_launchesWatch_andWaits() async {
        let setup = Setup()
        var requests: [StartRequest] = []
        setup.watchTransport.onStartRequest = { requests.append($0) }

        setup.start()
        await setup.starter.launchTask?.value

        #expect(setup.phone.isAwaitingOwner)
        #expect(requests.map(\.workoutID) == [setup.workoutID])
        #expect(requests.first?.config == setup.config)
        #expect(setup.launcher.configs == [setup.config])
    }

    @Test func watchConfirms_phoneFollowsAsViewer_andTimeoutDoesNothing() async {
        let setup = Setup()
        setup.start()
        await setup.starter.launchTask?.value

        setup.watchConfirms()
        setup.starter.handshakeTimedOut()

        #expect(setup.phone.role == .viewer)
        #expect(setup.phone.renderedState?.owner == .watch)
        #expect(setup.starter.lastFallbackDate == nil)
    }

    // MARK: - Fallback

    @Test func timeout_takesOverOnPhone_withTheSameWorkout() async {
        let setup = Setup()
        var seenByWatch: [TimerSyncPayload] = []
        setup.start()
        await setup.starter.launchTask?.value
        // Listen on the raw channel: the Watch hasn't started, so its controller expects nothing.
        setup.link.watchEnd.onPayload = { seenByWatch.append($0) }

        setup.starter.handshakeTimedOut()

        #expect(setup.phone.role == .owner)
        #expect(setup.phone.workoutID == setup.workoutID)
        #expect(setup.phone.renderedState?.owner == .phone)
        #expect(setup.starter.lastFallbackDate != nil)
        // A Watch that starts late finds the iPhone-owned state and yields (slice 5B).
        guard case .state(let published) = seenByWatch.last else {
            Issue.record("Expected the iPhone to publish its snapshot")
            return
        }
        #expect(published.owner == .phone && published.workoutID == setup.workoutID)
    }

    @Test func launchFailure_takesOverWithoutWaitingForTimeout() async {
        let setup = Setup()
        setup.launcher.fails = true

        setup.start()
        await setup.starter.launchTask?.value

        #expect(setup.phone.role == .owner)
        #expect(setup.phone.renderedState?.owner == .phone)
        #expect(setup.starter.lastFallbackDate != nil)
    }

    @Test func lateWatchSnapshot_afterTakeover_doesNotChangeOwner() async {
        let setup = Setup()
        setup.start()
        await setup.starter.launchTask?.value
        setup.starter.handshakeTimedOut()

        setup.watchConfirms()  // a crossed handshake: the Watch answers too late

        #expect(setup.phone.role == .owner)
        #expect(setup.phone.renderedState?.owner == .phone)
    }

    @Test func timeoutAfterCancel_doesNothing() async {
        let setup = Setup()
        setup.start()
        await setup.starter.launchTask?.value

        setup.starter.cancel()
        setup.phone.end()
        setup.starter.handshakeTimedOut()

        #expect(setup.phone.role == nil)
        #expect(setup.starter.lastFallbackDate == nil)
    }
}
