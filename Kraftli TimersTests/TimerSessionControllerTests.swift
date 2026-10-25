//
//  TimerSessionControllerTests.swift
//  Kraftli TimersTests
//
//  Owner + viewer pairs over a simulated link (ADR-006 / ADR-007).
//  All times come from a shared fake clock, so every scenario is deterministic.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct TimerSessionControllerTests {

    // MARK: - Fixtures

    /// A fake clock shared by both devices (their real clocks agree to within ms).
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)
        func advance(_ seconds: TimeInterval) { now += seconds }
    }

    /// Owner (Watch) and viewer (iPhone) connected by a `FakeLink`.
    @MainActor
    private struct Pair {
        let clock = Clock()
        let link = FakeLink()
        let owner: TimerSessionController
        let viewer: TimerSessionController
        let state: TimerState

        init(duration: TimeInterval = 600) {
            let clock = self.clock
            owner = TimerSessionController(
                transport: CompositeTimerSyncTransport(transports: [link.watchEnd]),
                now: { clock.now },
                schedulesCompletion: false
            )
            viewer = TimerSessionController(
                transport: CompositeTimerSyncTransport(transports: [link.phoneEnd]),
                now: { clock.now },
                schedulesCompletion: false
            )
            state = TimerState(
                workoutID: UUID(),
                owner: .watch,
                config: TimerConfig(
                    timerKindRaw: TimerKind.amrap.rawValue,
                    totalDuration: duration,
                    intervalCount: nil,
                    exerciseName: "Burpees"
                ),
                now: clock.now  // countdown now; the workout clock starts 3 s later
            )
            viewer.startAsViewer(workoutID: state.workoutID)
            owner.startAsOwner(state)
        }

        /// Elapsed workout time on each device at the current instant.
        var elapsed: (owner: TimeInterval?, viewer: TimeInterval?) {
            (owner.renderedState?.elapsed(at: clock.now), viewer.renderedState?.elapsed(at: clock.now))
        }
    }

    // MARK: - Start

    @Test func viewer_rendersOwnersFirstSnapshot() {
        let pair = Pair()

        #expect(pair.viewer.renderedState == pair.state)
        #expect(pair.viewer.role == .viewer && pair.owner.role == .owner)
    }

    @Test func viewer_cannotActBeforeFirstSnapshot() {
        let link = FakeLink()
        let viewer = TimerSessionController(
            transport: CompositeTimerSyncTransport(transports: [link.phoneEnd]),
            schedulesCompletion: false
        )
        viewer.startAsViewer(workoutID: UUID())

        viewer.pause()

        #expect(viewer.pendingIntents.isEmpty)
        #expect(link.phoneEnd.sentCount == 0)
    }

    // MARK: - Start handshake

    @Test func requestStart_sendsRequest_andAwaitsOwnersFirstSnapshot() {
        let link = FakeLink()
        let phone = TimerSessionController(
            transport: CompositeTimerSyncTransport(transports: [link.phoneEnd]),
            schedulesCompletion: false
        )
        let watchTransport = CompositeTimerSyncTransport(transports: [link.watchEnd])
        let watch = TimerSessionController(transport: watchTransport, schedulesCompletion: false)
        var requests: [StartRequest] = []
        watchTransport.onStartRequest = { requests.append($0) }
        let state = Pair().state

        phone.requestStart(StartRequest(workoutID: state.workoutID, config: state.config, requestedAt: Date()))
        #expect(phone.isAwaitingOwner && phone.workoutID == state.workoutID)
        #expect(requests.map(\.workoutID) == [state.workoutID])

        watch.startAsOwner(state)
        #expect(!phone.isAwaitingOwner)
        #expect(phone.renderedState == state)
    }

    @Test func stopBeforeOwnerAnswered_endsTheWorkoutOnceItStarts() {
        let link = FakeLink()
        let phone = TimerSessionController(
            transport: CompositeTimerSyncTransport(transports: [link.phoneEnd]),
            schedulesCompletion: false
        )
        let watch = TimerSessionController(
            transport: CompositeTimerSyncTransport(transports: [link.watchEnd]),
            schedulesCompletion: false
        )
        let state = Pair().state
        link.isConnected = false

        phone.requestStart(StartRequest(workoutID: state.workoutID, config: state.config, requestedAt: Date()))
        phone.stop()      // cancelled during "Starting on Watch…"
        phone.end()
        watch.startAsOwner(state)
        link.isConnected = true

        #expect(watch.confirmedState?.finish != nil)
    }

    // MARK: - Connected control

    @Test func viewerPause_showsImmediately_andOwnerConfirmsAtTapTime() {
        let pair = Pair()
        pair.clock.advance(13)  // 10 s into the workout

        pair.viewer.pause()

        #expect(pair.viewer.renderedState?.isPaused == true)
        #expect(pair.owner.renderedState?.isPaused == true)
        #expect(pair.viewer.pendingIntents.isEmpty)  // confirmed by the owner's snapshot
        pair.clock.advance(30)
        #expect(pair.elapsed.owner == 10 && pair.elapsed.viewer == 10)
    }

    @Test func viewerPause_deliveredLate_stillAppliesAtTapTime() {
        let pair = Pair()
        pair.clock.advance(13)
        pair.link.isConnected = false

        pair.viewer.pause()            // tapped at 10 s of workout time
        pair.clock.advance(2)          // reaches the owner 2 s later
        pair.link.isConnected = true

        #expect(pair.owner.renderedState?.elapsed(at: pair.clock.now) == 10)
        #expect(pair.elapsed.owner == pair.elapsed.viewer)
    }

    @Test func ownerPause_isFollowedByViewer() {
        let pair = Pair()
        pair.clock.advance(13)

        pair.owner.pause()
        pair.clock.advance(5)

        #expect(pair.viewer.renderedState?.isPaused == true)
        #expect(pair.elapsed.owner == 10 && pair.elapsed.viewer == 10)
        #expect(pair.viewer.lastRollbackDate == nil)
    }

    @Test func alternatingPauseResume_neverDrifts() {
        let pair = Pair()
        pair.clock.advance(3)
        for cycle in 0..<20 {
            pair.clock.advance(1)
            cycle.isMultiple(of: 2) ? pair.viewer.pause() : pair.owner.pause()
            pair.clock.advance(1)
            cycle.isMultiple(of: 2) ? pair.owner.resume() : pair.viewer.resume()
        }
        pair.clock.advance(1)

        #expect(pair.elapsed.owner == 21)
        #expect(pair.elapsed.owner == pair.elapsed.viewer)
    }

    // MARK: - Disconnected control (ADR-007 option B)

    @Test func offlinePauseAndResume_arriveAsOneBatch() {
        let pair = Pair()
        pair.clock.advance(13)
        pair.link.isConnected = false

        pair.viewer.pause()
        pair.clock.advance(10)
        pair.viewer.resume()

        #expect(pair.viewer.renderedState?.isPaused == false)
        #expect(pair.viewer.hasUnconfirmedChanges)
        #expect(pair.owner.renderedState?.isPaused == false)  // never heard of the pause

        pair.link.isConnected = true
        pair.clock.advance(5)

        #expect(pair.owner.confirmedState?.accumulatedPause == 10)
        #expect(!pair.viewer.hasUnconfirmedChanges)
        #expect(pair.elapsed.owner == 15 && pair.elapsed.viewer == 15)
        #expect(pair.viewer.lastRollbackDate == nil)
    }

    @Test func conflictingOfflinePause_ownerWins_andViewerSnapsBack() {
        let pair = Pair()
        pair.clock.advance(13)
        pair.link.isConnected = false

        pair.owner.pause()        // the wearer pauses and resumes on the Watch…
        pair.clock.advance(2)
        pair.owner.resume()
        pair.clock.advance(1)
        pair.viewer.pause()       // …while the disconnected phone pauses
        #expect(pair.viewer.renderedState?.isPaused == true)

        pair.link.isConnected = true

        #expect(pair.owner.renderedState?.isPaused == false)
        #expect(pair.viewer.renderedState?.isPaused == false)  // snapped back
        #expect(pair.viewer.lastRollbackDate == pair.clock.now)
        #expect(!pair.viewer.hasUnconfirmedChanges)
        pair.clock.advance(4)
        #expect(pair.elapsed.owner == pair.elapsed.viewer)
    }

    @Test func roundsCountedOnBothDevicesOffline_converge() {
        let pair = Pair()
        pair.clock.advance(5)
        pair.link.isConnected = false

        pair.owner.incrementRound()
        pair.owner.incrementRound()
        pair.viewer.incrementRound()
        #expect(pair.viewer.renderedState?.roundCount == 1)  // its own prediction

        pair.link.isConnected = true

        #expect(pair.owner.renderedState?.roundCount == 3)
        #expect(pair.viewer.renderedState?.roundCount == 3)
    }

    @Test func offlineStop_isAppliedOnReconnect_atTapTime() {
        let pair = Pair()
        pair.clock.advance(13)
        pair.link.isConnected = false

        pair.viewer.stop()
        #expect(pair.viewer.renderedState?.isFinished(at: pair.clock.now) == true)
        pair.clock.advance(20)
        pair.link.isConnected = true

        #expect(pair.owner.confirmedState?.finish == .stopped(at: pair.state.startDate.addingTimeInterval(10)))
        #expect(pair.elapsed.owner == 10 && pair.elapsed.viewer == 10)
    }

    @Test func snapshotsMissedWhileDisconnected_arriveOnReconnect() {
        let pair = Pair()
        pair.clock.advance(13)
        pair.link.isConnected = false

        pair.owner.pause()
        #expect(pair.viewer.renderedState?.isPaused == false)

        pair.link.isConnected = true

        #expect(pair.viewer.renderedState?.isPaused == true)
        #expect(pair.viewer.confirmedState == pair.owner.confirmedState)
    }

    // MARK: - Completion

    @Test func owner_completesAtEndTime_andViewerFollows() {
        let pair = Pair(duration: 60)
        pair.clock.advance(62)
        pair.owner.checkCompletion()
        #expect(pair.owner.confirmedState?.finish == nil)  // 59 s in — not yet

        pair.clock.advance(5)
        pair.owner.checkCompletion()

        let end = pair.state.startDate.addingTimeInterval(60)
        #expect(pair.owner.confirmedState?.finish == .completed(at: end))
        #expect(pair.viewer.confirmedState?.finish == .completed(at: end))
    }

    @Test func viewer_cannotCompleteWorkout() {
        let pair = Pair(duration: 60)
        pair.clock.advance(100)

        pair.viewer.checkCompletion()

        #expect(pair.owner.confirmedState?.finish == nil)
        #expect(pair.viewer.confirmedState?.finish == nil)
    }

    // MARK: - Lifecycle

    @Test func end_ignoresLaterTrafficForTheWorkout() {
        let pair = Pair()
        pair.viewer.end()
        pair.clock.advance(13)

        pair.owner.pause()

        #expect(pair.viewer.renderedState == nil)
        #expect(pair.viewer.role == nil)
    }

    @Test func renderedStateCallback_feedsEveryChange() {
        let pair = Pair()
        var seen: [Bool] = []
        pair.viewer.onRenderedStateChange = { seen.append($0.isPaused) }
        pair.clock.advance(13)

        pair.viewer.pause()   // prediction, then confirmation
        pair.clock.advance(1)
        pair.owner.resume()

        #expect(seen == [true, true, false])
    }
}
