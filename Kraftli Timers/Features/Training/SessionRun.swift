//
//  SessionRun.swift
//  Kraftli Timers
//
//  One run through a training session (UC-0015), as a value: the running order, where
//  the athlete is in it, and what each timer came to.
//

import Foundation

/// A session in running order, every loop unrolled: its steps once per round, and its
/// rest after each round except the last.
///
/// The one place this order is worked out. The length estimate, the shape bar and the
/// runner all read it, so they can't disagree on what comes when.
nonisolated enum SessionOrder {
    struct Item: Equatable, Sendable {
        enum Content: Equatable, Sendable {
            case step(SessionStep)
            case rest(seconds: Int)
        }

        let content: Content
        /// The loop the item belongs to, with the round it is in (counted from 1) and the
        /// loop's number of rounds. All `nil` outside a loop.
        let loopID: UUID?
        let loopRound: Int?
        let loopRounds: Int?

        var step: SessionStep? {
            if case .step(let step) = content { step } else { nil }
        }

        var isRest: Bool { step == nil }
    }

    static func items(of elements: [SessionElement]) -> [Item] {
        elements.flatMap { element -> [Item] in
            switch element {
            case .step(let step):
                return [Item(content: .step(step), loopID: nil, loopRound: nil, loopRounds: nil)]
            case .loop(let loop):
                return (1...max(loop.rounds, 1)).flatMap { round -> [Item] in
                    var items = loop.steps.map {
                        Item(content: .step($0), loopID: loop.id, loopRound: round, loopRounds: loop.rounds)
                    }
                    if loop.restSeconds > 0, round < loop.rounds {
                        items.append(Item(
                            content: .rest(seconds: loop.restSeconds),
                            loopID: loop.id, loopRound: round, loopRounds: loop.rounds
                        ))
                    }
                    return items
                }
            }
        }
    }
}

/// One run through a session: all the rules of UC-0015 that don't need a clock of their
/// own, a timer or a view. Every change takes the time it happens at, so the run is
/// tested with plain dates.
///
/// A struct like `SessionDraft`: the runner object holds one, changes it through these
/// methods, and SwiftUI redraws from the new value.
nonisolated struct SessionRun: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// Between steps: waiting for the athlete to start the current step. The session
        /// is paused.
        case upNext
        /// The current step's timer is running (countdown included).
        case running
        /// A loop's rest is counting down to `until`. The session is not paused.
        case resting(until: Date)
        case finished
    }

    enum Outcome: Equatable, Sendable {
        case completed
        /// Ended early with enough active time to be recorded (UC-0005 extension 1a).
        case stoppedEarly
        /// Skipped, or ended too early to be recorded: nothing is in the history.
        case skipped
    }

    /// What one timer of the run came to.
    struct StepResult: Equatable, Sendable {
        /// The timer's place in `items`.
        let index: Int
        let step: SessionStep
        let loopRound: Int?
        let outcome: Outcome
        /// Active time in seconds; 0 when skipped.
        let duration: TimeInterval
        let reps: Int?
        let roundsCounted: Int?
    }

    let name: String
    /// The session as it was when the run began: later edits don't reach a run.
    let items: [SessionOrder.Item]

    private(set) var phase: Phase
    /// The item the run is at; `items.count` once finished.
    private(set) var position = 0
    private(set) var results: [StepResult] = []
    /// True when the athlete ended the session before its last timer.
    private(set) var endedEarly = false
    /// The stretches in which the session wasn't paused: each from a step's start to its
    /// end, through a loop's rest if one followed. The gaps are the Health workout's pauses.
    private(set) var activeIntervals: [DateInterval] = []
    /// Time spent in loop rests, in seconds.
    private(set) var restTime: TimeInterval = 0

    private var activeSince: Date?
    private var restingSince: Date?

    init(name: String, elements: [SessionElement]) {
        self.name = name
        // A rest only makes sense between two timers. A saved session has none elsewhere
        // (a loop has at least one step), but a run must never wait on a rest forever.
        var items: [SessionOrder.Item] = []
        for item in SessionOrder.items(of: elements) where !item.isRest || items.last?.isRest == false {
            items.append(item)
        }
        if items.last?.isRest == true {
            items.removeLast()
        }
        self.items = items
        self.phase = items.isEmpty ? .finished : .upNext
    }

    // MARK: - Where the run is

    var currentItem: SessionOrder.Item? {
        items.indices.contains(position) ? items[position] : nil
    }

    /// The step that is up next or running; during a rest, the step that follows it.
    var currentStep: SessionStep? {
        items[min(position, items.count)...].lazy.compactMap(\.step).first
    }

    /// The loop round of `currentStep`, as (round, of rounds); `nil` outside a loop.
    var currentLoopRound: (round: Int, of: Int)? {
        guard let item = items[min(position, items.count)...].first(where: { !$0.isRest }),
              let round = item.loopRound, let rounds = item.loopRounds else { return nil }
        return (round, rounds)
    }

    /// The number of timers in the run; rests don't count.
    var timerCount: Int {
        items.count { !$0.isRest }
    }

    /// The number of `currentStep` among the timers, counted from 1.
    var timerNumber: Int {
        min(items[..<min(position, items.count)].count { !$0.isRest } + 1, timerCount)
    }

    /// The timer that ended last, for showing its result between steps.
    var lastResult: StepResult? {
        results.last
    }

    /// Timers that were completed or stopped early: the ones with a history entry.
    var recordedCount: Int {
        results.count { $0.outcome != .skipped }
    }

    /// The active time: every timer's, plus the loop rests. The waits between steps
    /// don't count.
    var totalTime: TimeInterval {
        results.reduce(restTime) { $0 + $1.duration }
    }

    /// The pauses of the session's Health workout: the gaps between the active stretches.
    var pauses: [DateInterval] {
        activeIntervals.gaps
    }

    /// True when the session was done in full: every timer completed, none skipped or
    /// stopped early. The completion sound and confetti are for that.
    var wasCompletedInFull: Bool {
        phase == .finished && !endedEarly && results.count == timerCount
            && results.allSatisfy { $0.outcome == .completed }
    }

    /// How late a rest's end may be noticed and the next timer still starts by itself.
    /// Later than that, the athlete wasn't there (the app was suspended): the session
    /// waits for them instead of running a timer nobody is ready for.
    static let restEndTolerance: TimeInterval = 5

    // MARK: - Changes

    /// The athlete starts the step that is up next.
    mutating func startStep(at now: Date) {
        guard phase == .upNext else { return }
        phase = .running
        activeSince = now
    }

    /// The running step's timer ended, by itself or because the athlete ended it.
    mutating func stepEnded(
        _ outcome: Outcome, duration: TimeInterval = 0, reps: Int? = nil, roundsCounted: Int? = nil, at now: Date
    ) {
        guard phase == .running, let item = currentItem, let step = item.step else { return }
        results.append(StepResult(
            index: position, step: step, loopRound: item.loopRound, outcome: outcome,
            duration: outcome == .skipped ? 0 : duration, reps: reps, roundsCounted: roundsCounted
        ))
        position += 1

        if case .rest(let seconds) = currentItem?.content {
            // The rest follows at once and the session stays active through it.
            restingSince = now
            phase = .resting(until: now.addingTimeInterval(TimeInterval(seconds)))
        } else {
            settle(at: now)
        }
    }

    /// The athlete skips the step that is up next. A rest right after it is skipped too:
    /// there is nothing to rest from.
    mutating func skip(at now: Date) {
        guard phase == .upNext, let item = currentItem, let step = item.step else { return }
        results.append(StepResult(
            index: position, step: step, loopRound: item.loopRound, outcome: .skipped,
            duration: 0, reps: nil, roundsCounted: nil
        ))
        position += 1
        if currentItem?.isRest == true {
            position += 1
        }
        settle(at: now)
    }

    /// The rest is over: its time ran out, or the athlete cut it short. The timer after
    /// it starts by itself, so the loop keeps its rhythm and the session stays active.
    ///
    /// A rest that ran out while nobody looked (the app was suspended) still ended when
    /// it was due, and the session then waits for the athlete.
    mutating func restEnded(at now: Date) {
        guard case .resting(let until) = phase else { return }
        let end = min(now, until)
        if let restingSince {
            restTime += max(end.timeIntervalSince(restingSince), 0)
        }
        restingSince = nil
        position += 1

        if currentItem?.step != nil, now.timeIntervalSince(until) <= Self.restEndTolerance {
            phase = .running
        } else {
            settle(at: end)
        }
    }

    /// The athlete ends the session: between steps, or during a rest, which ends with
    /// it. A running step has to end first.
    mutating func endSession(at now: Date) {
        switch phase {
        case .upNext:
            break
        case .resting(let until):
            let end = min(now, until)
            if let restingSince {
                restTime += max(end.timeIntervalSince(restingSince), 0)
            }
            restingSince = nil
            settle(at: end)
        case .running, .finished:
            return
        }
        endedEarly = true
        phase = .finished
    }

    /// Closes the active stretch and waits for the athlete, or finishes after the last item.
    private mutating func settle(at now: Date) {
        if let activeSince {
            activeIntervals.append(DateInterval(start: activeSince, end: max(now, activeSince)))
        }
        activeSince = nil
        phase = position < items.count ? .upNext : .finished
    }
}

extension Array where Element == DateInterval {
    /// The stretches between consecutive intervals, where one ends before the next begins.
    nonisolated var gaps: [DateInterval] {
        zip(self, dropFirst()).compactMap { earlier, later in
            later.start > earlier.end ? DateInterval(start: earlier.end, end: later.start) : nil
        }
    }
}
