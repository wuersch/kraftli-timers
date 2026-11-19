//
//  EarlyStopTests.swift
//  Kraftli TimersTests
//
//  The rule for workouts ended early (UC-0005 extensions 1a–1b).
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct EarlyStopTests {

    // MARK: - Fixtures

    /// The workout clock starts at `start`; no countdown, to keep the arithmetic plain.
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    private func state(_ config: TimerConfig) -> TimerState {
        TimerState(workoutID: UUID(), owner: .phone, config: config, startDate: start)
    }

    private let emom = TimerConfig(kind: .emom, totalDuration: 600, intervalCount: 10, exerciseName: "Burpees")
    private let amrap = TimerConfig(kind: .amrap, totalDuration: 600, intervalCount: nil, exerciseName: "Squats")
    private let forTime = TimerConfig(kind: .forTime, totalDuration: nil, intervalCount: nil, exerciseName: "Push-ups", targetReps: 50)

    // MARK: - Nothing recorded (1b)

    @Test func stoppedInTheCountdown_isDiscarded() {
        let countingDown = TimerState(workoutID: UUID(), owner: .phone, config: amrap, now: start)

        #expect(EarlyStop(of: countingDown, at: at(2)) == .discard)
    }

    @Test func lessThanAMinuteOfActiveTime_isDiscarded() {
        #expect(EarlyStop(of: state(amrap), at: at(59.9)) == .discard)
    }

    @Test func pausesDontCountTowardTheMinute() {
        // Two minutes on the clock, but paused after 30 s.
        var paused = state(amrap)
        paused.pausedAt = at(30)
        #expect(EarlyStop(of: paused, at: at(120)) == .discard)

        // Resumed after a 100 s pause: 150 s on the clock are 50 s of activity.
        var resumed = state(amrap)
        resumed.accumulatedPause = 100
        #expect(EarlyStop(of: resumed, at: at(150)) == .discard)
    }

    // MARK: - Recorded as stopped early (1a)

    @Test func fromOneMinuteOn_theActiveTimeIsRecorded_inWholeSeconds() {
        #expect(EarlyStop(of: state(amrap), at: at(60)) == .record(activeTime: 60, reps: nil, rounds: 0))
        #expect(EarlyStop(of: state(amrap), at: at(163.8)) == .record(activeTime: 163, reps: nil, rounds: 0))
    }

    @Test func amrap_recordsTheRoundsCountedSoFar() {
        var counted = state(amrap)
        counted.roundCount = 5

        #expect(EarlyStop(of: counted, at: at(163)) == .record(activeTime: 163, reps: nil, rounds: 5))
    }

    @Test func emom_recordsTheIntervalsFullyDone() {
        // Ten one-minute intervals; the third is under way.
        #expect(EarlyStop(of: state(emom), at: at(150)) == .record(activeTime: 150, reps: 2, rounds: nil))
    }

    @Test func forTime_recordsNoReps_becauseTheyAreUnknown() {
        #expect(EarlyStop(of: state(forTime), at: at(95)) == .record(activeTime: 95, reps: nil, rounds: nil))
    }

    @Test func stoppedState_isJudgedAtItsStop_notAtTheTimeOfAsking() {
        var stopped = state(amrap)
        stopped.finish = .stopped(at: at(45))
        #expect(EarlyStop(of: stopped, at: at(500)) == .discard)

        stopped.finish = .stopped(at: at(200))
        #expect(EarlyStop(of: stopped, at: at(500)) == .record(activeTime: 200, reps: nil, rounds: 0))
    }

    // MARK: - Not an early stop

    @Test func completedWorkout_isNoEarlyStop() {
        var completed = state(amrap)
        completed.finish = .completed(at: at(600))
        #expect(EarlyStop(of: completed, at: at(700)) == nil)

        // Time ran out, though the owner hasn't marked it completed yet.
        #expect(EarlyStop(of: state(amrap), at: at(600)) == nil)

        var done = state(forTime)
        done.finish = .completed(at: at(30))
        #expect(EarlyStop(of: done, at: at(31)) == nil)
    }
}
