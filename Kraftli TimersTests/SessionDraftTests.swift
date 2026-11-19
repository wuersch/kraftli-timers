//
//  SessionDraftTests.swift
//  Kraftli TimersTests
//
//  The editing rules of the session editor (UC-0013).
//

import Foundation
import SwiftData
import Testing
@testable import Kraftli_Timers

@MainActor
struct SessionDraftTests {
    private func step(_ minutes: Int = 1) -> SessionStep {
        SessionStep(kind: .amrap, exerciseId: nil, durationInterval: TimeInterval(minutes * 60), targetReps: nil)
    }

    // MARK: - Validation (extensions 5a–5c)

    @Test func validDraft_hasNoIssues() {
        let draft = SessionDraft(name: "Legs", elements: [.step(step())])

        #expect(draft.issues(otherNames: ["Upper Body"]).isEmpty)
    }

    @Test func emptyOrBlankName_isAnIssue() {
        #expect(SessionDraft(name: "", elements: [.step(step())]).issues(otherNames: []) == [.noName])
        #expect(SessionDraft(name: "  ", elements: [.step(step())]).issues(otherNames: []) == [.noName])
    }

    @Test func nameOfAnotherSession_isAnIssue() {
        let draft = SessionDraft(name: " legs", elements: [.step(step())])

        #expect(draft.issues(otherNames: ["Legs"]) == [.nameTaken])
    }

    @Test func sessionWithoutElements_andLoopWithoutSteps_areIssues() {
        #expect(SessionDraft(name: "Legs").issues(otherNames: []) == [.noElements])

        var draft = SessionDraft(name: "Legs")
        let loopID = draft.addLoop()
        #expect(draft.issues(otherNames: []) == [.emptyLoop(loopID)])
    }

    // MARK: - Adding and changing

    @Test func steps_areAppendedToTheSession_orToALoop() throws {
        var draft = SessionDraft()
        let first = step(1), inLoop = step(2)

        draft.add(first)
        let loopID = draft.addLoop()
        draft.add(inLoop, toLoop: loopID)

        #expect(draft.elements.count == 2)
        #expect(draft.elements[0] == .step(first))
        let loop = try #require(draft.elements[1].loop)
        #expect(loop.steps == [inLoop])
        #expect(loop.rounds == 2)
        #expect(loop.restSeconds == 0)
    }

    @Test func update_replacesTheStep_onEitherLevel() throws {
        var draft = SessionDraft()
        let top = step(1), nested = step(2)
        draft.add(top)
        let loopID = draft.addLoop()
        draft.add(nested, toLoop: loopID)

        var changedTop = top
        changedTop.durationInterval = 600
        var changedNested = nested
        changedNested.durationInterval = 900
        draft.update(changedTop)
        draft.update(changedNested)

        #expect(draft.elements[0] == .step(changedTop))
        let loop = try #require(draft.elements[1].loop)
        #expect(loop.steps == [changedNested])
    }

    @Test func loopSettings_areKeptWithinTheirLimits() throws {
        var draft = SessionDraft()
        let loopID = draft.addLoop()

        draft.setLoop(loopID, rounds: 99, restSeconds: 9_999)
        let high = try #require(draft.elements[0].loop)
        #expect(high.rounds == 20)
        #expect(high.restSeconds == 600)

        draft.setLoop(loopID, rounds: 0, restSeconds: -5)
        let low = try #require(draft.elements[0].loop)
        #expect(low.rounds == 2)
        #expect(low.restSeconds == 0)
    }

    @Test func remove_takesAStepOrAWholeLoop() throws {
        var draft = SessionDraft()
        let top = step(1), nested = step(2)
        draft.add(top)
        let loopID = draft.addLoop()
        draft.add(nested, toLoop: loopID)

        draft.remove(nested.id)
        let loop = try #require(draft.elements[1].loop)
        #expect(loop.steps.isEmpty)

        draft.remove(loopID)
        #expect(draft.elements == [.step(top)])
    }

    // MARK: - Reordering (extension 3c)

    @Test func blockDroppedBeforeOrAfterAnother_landsThere() {
        let a = step(1), b = step(2), c = step(3)
        var draft = SessionDraft(elements: [.step(a), .step(b), .step(c)])

        draft.drop(a.id, at: .after(c.id))
        #expect(draft.elements.map(\.id) == [b.id, c.id, a.id])

        draft.drop(a.id, at: .before(c.id))
        #expect(draft.elements.map(\.id) == [b.id, a.id, c.id])
    }

    @Test func timersOfALoop_reorderWithinIt_andALoopMovesAsAWhole() throws {
        let top = step(1), nestedA = step(2), nestedB = step(3)
        var draft = SessionDraft(elements: [.step(top)])
        let loopID = draft.addLoop()
        draft.add(nestedA, toLoop: loopID)
        draft.add(nestedB, toLoop: loopID)

        draft.drop(nestedB.id, at: .before(nestedA.id))
        #expect(try #require(draft.elements[1].loop).steps.map(\.id) == [nestedB.id, nestedA.id])

        draft.drop(loopID, at: .before(top.id))
        #expect(draft.elements.map(\.id) == [loopID, top.id])
        #expect(try #require(draft.elements[0].loop).steps.count == 2)
    }

    @Test func dropThatChangesNothing_isRecognised() {
        let a = step(1), b = step(2)
        let draft = SessionDraft(elements: [.step(a), .step(b)])

        #expect(!draft.canDrop(a.id, at: .before(a.id)))
        #expect(!draft.canDrop(a.id, at: .before(b.id)))
        #expect(!draft.canDrop(b.id, at: .after(a.id)))
        #expect(!draft.canDrop(a.id, at: .after(UUID())))
        #expect(draft.canDrop(a.id, at: .after(b.id)))
    }

    // MARK: - Moving between levels (extension 3d)

    @Test func timerDroppedNextToATimerInALoop_goesIntoTheLoop() throws {
        let top = step(1), nestedA = step(2), nestedB = step(3)
        var draft = SessionDraft(elements: [.step(top)])
        let loopID = draft.addLoop()
        draft.add(nestedA, toLoop: loopID)
        draft.add(nestedB, toLoop: loopID)

        draft.drop(top.id, at: .after(nestedA.id))

        #expect(draft.elements.map(\.id) == [loopID])
        #expect(try #require(draft.elements[0].loop).steps.map(\.id) == [nestedA.id, top.id, nestedB.id])
    }

    @Test func timerDroppedNextToASessionBlock_leavesItsLoop() throws {
        let top = step(1), nestedA = step(2), nestedB = step(3)
        var draft = SessionDraft()
        let loopID = draft.addLoop()
        draft.add(nestedA, toLoop: loopID)
        draft.add(nestedB, toLoop: loopID)
        draft.add(top)

        draft.drop(nestedA.id, at: .after(top.id))
        #expect(draft.elements.map(\.id) == [loopID, top.id, nestedA.id])

        // Next to its own loop, the last timer leaves it too. The loop stays, empty.
        draft.drop(nestedB.id, at: .before(loopID))
        #expect(draft.elements.map(\.id) == [nestedB.id, loopID, top.id, nestedA.id])
        #expect(try #require(draft.elements[1].loop).steps.isEmpty)
        #expect(draft.issues(otherNames: []).contains(.emptyLoop(loopID)))
    }

    @Test func timerDroppedBetweenTwoLoops_landsBetweenThem() {
        let nested = step(1)
        var draft = SessionDraft()
        let first = draft.addLoop(), second = draft.addLoop()
        draft.add(nested, toLoop: first)

        draft.drop(nested.id, at: .after(first))

        #expect(draft.elements.map(\.id) == [first, nested.id, second])
    }

    @Test func timerDroppedNextToATimerOfAnotherLoop_changesLoops() throws {
        let a = step(1), b = step(2)
        var draft = SessionDraft()
        let first = draft.addLoop(), second = draft.addLoop()
        draft.add(a, toLoop: first)
        draft.add(b, toLoop: second)

        draft.drop(a.id, at: .before(b.id))

        #expect(try #require(draft.elements[0].loop).steps.isEmpty)
        #expect(try #require(draft.elements[1].loop).steps.map(\.id) == [a.id, b.id])
    }

    @Test func timerDroppedAtTheEndOfALoop_becomesItsLastTimer() throws {
        let top = step(1), nested = step(2)
        var draft = SessionDraft(elements: [.step(top)])
        let filled = draft.addLoop(), empty = draft.addLoop()
        draft.add(nested, toLoop: filled)

        draft.drop(top.id, at: .endOfLoop(empty))
        #expect(draft.elements.map(\.id) == [filled, empty])
        #expect(try #require(draft.elements[1].loop).steps.map(\.id) == [top.id])

        draft.drop(top.id, at: .endOfLoop(filled))
        #expect(try #require(draft.elements[0].loop).steps.map(\.id) == [nested.id, top.id])
        #expect(try #require(draft.elements[1].loop).steps.isEmpty)
    }

    @Test func loop_neverGoesIntoALoop_itGoesNextToIt() throws {
        let nested = step(1)
        var draft = SessionDraft()
        let first = draft.addLoop(), second = draft.addLoop()
        draft.add(nested, toLoop: first)

        #expect(draft.resolved(.before(nested.id), for: second) == .before(first))
        draft.drop(second, at: .before(nested.id))
        #expect(draft.elements.map(\.id) == [second, first])

        #expect(draft.resolved(.endOfLoop(second), for: first) == .after(second))
        draft.drop(first, at: .endOfLoop(second))
        #expect(draft.elements.map(\.id) == [second, first])
        #expect(try #require(draft.elements[1].loop).steps.map(\.id) == [nested.id])

        // Aimed at its own timer or its own end, a loop stays where it is.
        #expect(!draft.canDrop(first, at: .after(nested.id)))
        #expect(!draft.canDrop(first, at: .endOfLoop(first)))
    }

    @Test func loopMoves_areOfferedToTimersInOrNextToALoop() {
        let before = step(1), nested = step(2), after = step(3), far = step(4)
        var draft = SessionDraft(elements: [.step(before)])
        let loopID = draft.addLoop()
        draft.add(nested, toLoop: loopID)
        draft.add(after)
        draft.add(far)

        #expect(draft.loopMoves(for: before.id) == [.intoLoopBelow])
        #expect(draft.loopMoves(for: nested.id) == [.outOfLoop])
        #expect(draft.loopMoves(for: after.id) == [.intoLoopAbove])
        #expect(draft.loopMoves(for: far.id).isEmpty)
        #expect(draft.loopMoves(for: loopID).isEmpty)
    }

    @Test func loopMoves_keepTheRunningOrder() throws {
        let before = step(1), nestedA = step(2), nestedB = step(3), after = step(4)
        var draft = SessionDraft(elements: [.step(before)])
        let loopID = draft.addLoop()
        draft.add(nestedA, toLoop: loopID)
        draft.add(nestedB, toLoop: loopID)
        draft.add(after)

        draft.move(before.id, .intoLoopBelow)
        draft.move(after.id, .intoLoopAbove)
        #expect(draft.elements.map(\.id) == [loopID])
        #expect(try #require(draft.elements[0].loop).steps.map(\.id) == [before.id, nestedA.id, nestedB.id, after.id])

        // Out again: the first timer lands above the loop, any other below it.
        draft.move(before.id, .outOfLoop)
        draft.move(after.id, .outOfLoop)
        #expect(draft.elements.map(\.id) == [before.id, loopID, after.id])

        // Into an empty loop.
        var empty = SessionDraft(elements: [.step(before)])
        let emptyLoop = empty.addLoop()
        empty.move(before.id, .intoLoopBelow)
        #expect(try #require(empty.elements.first { $0.id == emptyLoop }?.loop).steps.map(\.id) == [before.id])
    }

    @Test func moveByOne_stopsAtTheEnds() {
        let a = step(1), b = step(2)
        var draft = SessionDraft(elements: [.step(a), .step(b)])

        #expect(!draft.canMove(a.id, by: -1))
        #expect(draft.canMove(a.id, by: 1))

        draft.move(a.id, by: 1)
        #expect(draft.elements.map(\.id) == [b.id, a.id])
        #expect(!draft.canMove(a.id, by: 1))
    }

    // MARK: - Copies and saving

    @Test func copy_getsANewName_andElementsOfItsOwn() throws {
        let nested = step(2)
        let loop = SessionLoop(rounds: 3, restSeconds: 60, steps: [nested])
        let session = TrainingSession(name: "Legs", elements: [.step(step(1)), .loop(loop)])

        let copy = SessionDraft(copyOf: session, existingNames: ["Legs"])

        #expect(copy.name == "Legs 2")
        #expect(copy.elements.count == 2)
        #expect(Set(copy.elements.map(\.id)).isDisjoint(with: session.elements.map(\.id)))
        let copiedLoop = try #require(copy.elements[1].loop)
        #expect(copiedLoop.rounds == 3)
        #expect(copiedLoop.restSeconds == 60)
        #expect(copiedLoop.steps.first?.id != nested.id)
        #expect(copiedLoop.steps.first?.durationInterval == nested.durationInterval)
    }

    @Test func save_insertsANewSession_orChangesTheEditedOne() throws {
        let container = try makeInMemoryContainer(for: TrainingSession.self, WeekPlan.self)
        let context = container.mainContext
        let first = step(1)

        SessionDraft(name: " Legs ", elements: [.step(first)]).save(editing: nil, in: context)
        try context.save()
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        #expect(sessions.map(\.name) == ["Legs"])
        #expect(sessions[0].elements == [.step(first)])

        var draft = SessionDraft(session: sessions[0])
        draft.name = "Legs & Core"
        draft.add(step(2))
        draft.save(editing: sessions[0], in: context)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<TrainingSession>())
        #expect(saved.count == 1)
        #expect(saved[0].name == "Legs & Core")
        #expect(saved[0].elements.count == 2)
    }

    /// The edited session can be deleted on another device while the editor is open.
    @Test func save_ofASessionDeletedMeanwhile_storesTheDraftAsANewSession() throws {
        let container = try makeInMemoryContainer(for: TrainingSession.self, WeekPlan.self)
        let context = container.mainContext
        let session = TrainingSession(name: "Legs", elements: [.step(step(1))])
        context.insert(session)
        try context.save()
        var draft = SessionDraft(session: session)
        draft.name = "Legs & Core"

        context.delete(session)
        try context.save()
        draft.save(editing: session, in: context)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<TrainingSession>())
        #expect(saved.map(\.name) == ["Legs & Core"])
        #expect(saved.first?.id != session.id)
    }
}

private extension SessionElement {
    /// The loop, if the element is one. With `try #require` a test stops with a failure
    /// when it isn't, instead of passing without having checked anything.
    var loop: SessionLoop? {
        if case .loop(let loop) = self { loop } else { nil }
    }
}
