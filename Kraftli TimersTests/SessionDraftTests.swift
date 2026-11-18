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

    @Test func steps_areAppendedToTheSession_orToALoop() {
        var draft = SessionDraft()
        let first = step(1), inLoop = step(2)

        draft.add(first)
        let loopID = draft.addLoop()
        draft.add(inLoop, toLoop: loopID)

        #expect(draft.elements.count == 2)
        #expect(draft.elements[0] == .step(first))
        guard case .loop(let loop) = draft.elements[1] else {
            Issue.record("expected a loop")
            return
        }
        #expect(loop.steps == [inLoop])
        #expect(loop.rounds == 2)
        #expect(loop.restSeconds == 0)
    }

    @Test func update_replacesTheStep_onEitherLevel() {
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
        guard case .loop(let loop) = draft.elements[1] else {
            Issue.record("expected a loop")
            return
        }
        #expect(loop.steps == [changedNested])
    }

    @Test func loopSettings_areKeptWithinTheirLimits() {
        var draft = SessionDraft()
        let loopID = draft.addLoop()

        draft.setLoop(loopID, rounds: 99, restSeconds: 9_999)
        guard case .loop(let high) = draft.elements[0] else { return }
        #expect(high.rounds == 20)
        #expect(high.restSeconds == 600)

        draft.setLoop(loopID, rounds: 0, restSeconds: -5)
        guard case .loop(let low) = draft.elements[0] else { return }
        #expect(low.rounds == 2)
        #expect(low.restSeconds == 0)
    }

    @Test func remove_takesAStepOrAWholeLoop() {
        var draft = SessionDraft()
        let top = step(1), nested = step(2)
        draft.add(top)
        let loopID = draft.addLoop()
        draft.add(nested, toLoop: loopID)

        draft.remove(nested.id)
        guard case .loop(let loop) = draft.elements[1] else { return }
        #expect(loop.steps.isEmpty)

        draft.remove(loopID)
        #expect(draft.elements == [.step(top)])
    }

    // MARK: - Reordering (extension 3c)

    @Test func droppingABlockOnAnother_takesItsPlace() {
        let a = step(1), b = step(2), c = step(3)
        var draft = SessionDraft(elements: [.step(a), .step(b), .step(c)])

        draft.move(a.id, onto: c.id)
        #expect(draft.elements.map(\.id) == [b.id, c.id, a.id])

        draft.move(a.id, onto: b.id)
        #expect(draft.elements.map(\.id) == [a.id, b.id, c.id])
    }

    @Test func blocks_onlyMoveWithinTheirLevel() {
        let top = step(1), nestedA = step(2), nestedB = step(3)
        var draft = SessionDraft(elements: [.step(top)])
        let loopID = draft.addLoop()
        draft.add(nestedA, toLoop: loopID)
        draft.add(nestedB, toLoop: loopID)
        let before = draft

        draft.move(top.id, onto: nestedA.id)
        draft.move(nestedA.id, onto: top.id)
        #expect(draft == before)

        draft.move(nestedB.id, onto: nestedA.id)
        guard case .loop(let loop) = draft.elements[1] else { return }
        #expect(loop.steps.map(\.id) == [nestedB.id, nestedA.id])

        // A loop moves as a whole, with its steps.
        draft.move(loopID, onto: top.id)
        #expect(draft.elements.map(\.id) == [loopID, top.id])
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

    @Test func copy_getsANewName_andElementsOfItsOwn() {
        let nested = step(2)
        let loop = SessionLoop(rounds: 3, restSeconds: 60, steps: [nested])
        let session = TrainingSession(name: "Legs", elements: [.step(step(1)), .loop(loop)])

        let copy = SessionDraft(copyOf: session, existingNames: ["Legs"])

        #expect(copy.name == "Legs 2")
        #expect(copy.elements.count == 2)
        #expect(Set(copy.elements.map(\.id)).isDisjoint(with: session.elements.map(\.id)))
        guard case .loop(let copiedLoop) = copy.elements[1] else { return }
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
}
