//
//  WatchSessionTests.swift
//  Kraftli TimersTests
//
//  The Watch's part in a training session run on the iPhone (UC-0015, ADR-0012): one
//  Health session held across the steps, driven by the iPhone's status.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct WatchSessionTests {

    // MARK: - Fixtures

    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)
        func advance(_ seconds: TimeInterval) { now += seconds }
    }

    /// Stands in for the Watch's HealthKit session.
    @MainActor
    private final class FakeHealth {
        var starts = 0
        var discards = 0
        var pauses = 0
        var resumes = 0
        var saved: [SessionContext] = []
    }

    /// iPhone and Watch controllers over a `FakeLink`, with the Watch's starter and follower.
    @MainActor
    private struct Setup {
        let clock = Clock()
        let link = FakeLink()
        let health = FakeHealth()
        let phone: TimerSessionController
        let watch: TimerSessionController
        let starter: WatchWorkoutStarter
        let follower: WatchSessionFollower
        let session = SessionContext(runID: UUID(), name: "Full Body")
        let config = TimerConfig(kind: .amrap, totalDuration: 240, intervalCount: nil, exerciseName: "Push-ups")

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
            follower = WatchSessionFollower(
                pauseHealthSession: { health.pauses += 1 },
                resumeHealthSession: { health.resumes += 1 },
                saveHealthSession: { health.saved.append($0) },
                discardHealthSession: { health.discards += 1 }
            )
            starter = WatchWorkoutStarter(
                controller: watch,
                transport: watchTransport,
                sessionFollower: follower,
                startHealthSession: { _ in health.starts += 1 },
                discardHealthSession: { health.discards += 1 },
                now: { clock.now },
                schedulesWatchdog: false
            )
        }

        /// The iPhone asks the Watch to start a step of the session.
        @discardableResult
        func phoneRequestsStep(of session: SessionContext? = nil) -> StartRequest {
            let request = StartRequest(
                workoutID: UUID(), config: config, requestedAt: clock.now, session: session ?? self.session
            )
            phone.requestStart(request)
            return request
        }

        /// The first step: requested, and owned by the Watch once its Health session runs.
        @discardableResult
        func startFirstStep() async -> StartRequest {
            let request = phoneRequestsStep()
            await starter.ownershipTask?.value
            return request
        }

        func status(_ sequence: Int, _ phase: SessionStatus.Phase, runID: UUID? = nil) -> SessionStatus {
            SessionStatus(runID: runID ?? session.runID, name: session.name, sequence: sequence, phase: phase)
        }
    }

    // MARK: - Holding the Health session

    @Test func firstStepTheWatchOwns_makesItsHealthSessionTheRuns() async {
        let setup = Setup()

        let request = await setup.startFirstStep()

        #expect(setup.health.starts == 1)
        #expect(setup.watch.confirmedState?.owner == .watch)
        #expect(setup.follower.isHolding(setup.session.runID))
        #expect(setup.starter.isSessionStep(request.workoutID))
    }

    @Test func laterStep_isOwnedAtOnce_withoutAnotherHealthSession() async {
        let setup = Setup()
        await setup.startFirstStep()
        setup.starter.workoutEnded()   // the first step's screen closed

        // Well past the window in which a request shares a session start.
        setup.clock.advance(120)
        let second = setup.phoneRequestsStep()

        #expect(setup.health.starts == 1)
        #expect(setup.health.discards == 0)
        #expect(setup.watch.role == .owner)
        #expect(setup.watch.workoutID == second.workoutID)
        #expect(setup.phone.confirmedState?.owner == .watch)
        #expect(setup.starter.requestedWorkout == second)
    }

    @Test func appLaunchedForALaterStep_doesNotStartAnotherHealthSession() async {
        let setup = Setup()
        await setup.startFirstStep()
        setup.starter.workoutEnded()
        setup.clock.advance(120)

        setup.starter.watchAppLaunched { setup.health.starts += 1 }
        await Task.yield()

        #expect(setup.health.starts == 1)
    }

    @Test func laterStepThatFallsBackToTheiPhone_leavesTheHealthSessionWithTheWatch() async {
        let setup = Setup()
        await setup.startFirstStep()
        setup.starter.workoutEnded()

        // The Watch misses the request; the iPhone runs the step itself.
        setup.link.isConnected = false
        let request = setup.phoneRequestsStep()
        setup.phone.startAsOwner(
            TimerState(workoutID: request.workoutID, owner: .phone, config: setup.config, now: setup.clock.now)
        )
        setup.link.isConnected = true

        #expect(setup.health.discards == 0)
        #expect(setup.follower.isHolding(setup.session.runID))
    }

    @Test func firstStepTheiPhoneTookOver_isNotHeld() async {
        let setup = Setup()

        // The iPhone's snapshot arrives before the Watch's Health session is up.
        let request = setup.phoneRequestsStep()
        setup.phone.startAsOwner(
            TimerState(workoutID: request.workoutID, owner: .phone, config: setup.config, now: setup.clock.now)
        )
        await setup.starter.ownershipTask?.value

        #expect(setup.follower.held == nil)
        // Yielded as for a single workout: the Watch's Health session is not kept.
        #expect(setup.health.discards >= 1)
    }

    @Test func workoutStartedOnTheWatch_takesTheHealthSessionOver() async {
        let setup = Setup()
        await setup.startFirstStep()
        setup.starter.workoutEnded()

        setup.starter.startOnWatch(workoutID: UUID(), config: setup.config)

        #expect(setup.follower.held == nil)
        #expect(!setup.starter.isSessionStep(setup.watch.workoutID ?? UUID()))
    }

    @Test func singleWorkout_isNoSessionStep() async {
        let setup = Setup()
        let request = StartRequest(workoutID: UUID(), config: setup.config, requestedAt: setup.clock.now)

        setup.phone.requestStart(request)
        await setup.starter.ownershipTask?.value

        #expect(setup.follower.held == nil)
        #expect(!setup.starter.isSessionStep(request.workoutID))
    }

    // MARK: - Following the session's progress

    @Test func status_pausesBetweenSteps_andRunsThroughStepsAndRests() async {
        let setup = Setup()
        await setup.startFirstStep()

        setup.phone.send(setup.status(1, .upNext))
        #expect(setup.health.pauses == 1)

        setup.phone.send(setup.status(2, .running))
        setup.phone.send(setup.status(3, .resting(until: setup.clock.now.addingTimeInterval(60))))
        #expect(setup.health.resumes == 2)
        #expect(setup.health.pauses == 1)
        #expect(setup.follower.status?.sequence == 3)
    }

    @Test func finishedSession_isSavedOnce_andLetGo() async {
        let setup = Setup()
        await setup.startFirstStep()

        setup.phone.send(setup.status(1, .finished(save: true)))
        setup.phone.send(setup.status(1, .finished(save: true)))   // the copy from another channel

        #expect(setup.health.saved == [setup.session])
        #expect(setup.health.discards == 0)
        #expect(setup.follower.held == nil)
    }

    @Test func finishedSessionWithNothingRecorded_isDiscarded() async {
        let setup = Setup()
        await setup.startFirstStep()

        setup.phone.send(setup.status(1, .finished(save: false)))

        #expect(setup.health.saved.isEmpty)
        #expect(setup.health.discards == 1)
        #expect(setup.follower.held == nil)
    }

    @Test func statusOfARunTheWatchDoesNotHold_isIgnored() async {
        let setup = Setup()
        await setup.startFirstStep()

        setup.phone.send(setup.status(1, .finished(save: true), runID: UUID()))

        #expect(setup.health.saved.isEmpty)
        #expect(setup.follower.isHolding(setup.session.runID))
    }

    @Test func staleStatus_isDropped() async {
        let setup = Setup()
        await setup.startFirstStep()

        setup.phone.send(setup.status(5, .running))
        setup.phone.send(setup.status(4, .upNext))   // arrives late

        #expect(setup.health.pauses == 0)
        #expect(setup.follower.status?.sequence == 5)
    }

    @Test func statusSentWhileDisconnected_arrivesInOrderOnReconnect() async {
        let setup = Setup()
        await setup.startFirstStep()

        setup.link.isConnected = false
        setup.phone.send(setup.status(1, .upNext))
        setup.phone.send(setup.status(2, .finished(save: true)))
        #expect(setup.health.saved.isEmpty)

        setup.link.isConnected = true

        #expect(setup.health.pauses == 1)
        #expect(setup.health.saved == [setup.session])
    }

    // MARK: - Wire format

    @Test func startRequestFromAnAppWithoutSessions_stillDecodes() throws {
        let old = """
        {"workoutID":"\(UUID().uuidString)","requestedAt":0,
         "config":{"timerKindRaw":"AMRAP","totalDuration":240,"exerciseName":"Push-ups"}}
        """
        let request = try JSONDecoder().decode(StartRequest.self, from: Data(old.utf8))

        #expect(request.session == nil)
        #expect(request.config.kind == .amrap)
    }

    @Test func sessionStatus_survivesTheWire() throws {
        var status = SessionStatus(
            runID: UUID(), name: "Full Body", sequence: 7,
            phase: .resting(until: Date(timeIntervalSince1970: 1_000_060))
        )
        status.step = TimerConfig(kind: .amrap, totalDuration: 240, intervalCount: nil, exerciseName: "Push-ups")
        status.timerNumber = 4
        status.timerCount = 8
        status.loopRound = 2
        status.loopRounds = 3

        let payload = try TimerSyncPayload(data: TimerSyncPayload.sessionStatus(status).encoded())

        #expect(payload == .sessionStatus(status))
        #expect(status.isActive)
    }
}
