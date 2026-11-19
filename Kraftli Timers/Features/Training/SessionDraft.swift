//
//  SessionDraft.swift
//  Kraftli Timers
//
//  The values the session editor works on, with the rules for editing and saving them.
//

import Foundation
import SwiftData

/// A training session while it is being edited (UC-0013).
///
/// A value type, like `PresetDraft`: the editor keeps one in `@State` and nothing reaches
/// the stored `TrainingSession` until `save` is called. Cancelling drops the draft.
/// Every editing rule lives here, so it can be tested without a view.
struct SessionDraft: Equatable {
    var name: String
    var elements: [SessionElement]

    /// A draft for a new session.
    init(name: String = "", elements: [SessionElement] = []) {
        self.name = name
        self.elements = elements
    }

    /// A draft for editing `session`.
    init(session: TrainingSession) {
        self.init(name: session.name, elements: session.elements)
    }

    /// A draft for a copy of `session` under a new name. The copy's steps and loops get
    /// ids of their own.
    init(copyOf session: TrainingSession, existingNames: [String]) {
        self.init(
            name: SessionNaming.copyName(of: session.name, existing: existingNames),
            elements: session.elements.map { element in
                switch element {
                case .step(var step):
                    step.id = UUID()
                    return .step(step)
                case .loop(var loop):
                    loop.id = UUID()
                    loop.steps = loop.steps.map { step in
                        var copy = step
                        copy.id = UUID()
                        return copy
                    }
                    return .loop(loop)
                }
            }
        )
    }

    // MARK: - Validation

    /// What keeps the draft from being saved.
    enum Issue: Equatable {
        case noName
        case nameTaken
        case noElements
        case emptyLoop(UUID)

        var message: String {
            switch self {
            case .noName: "Give the session a name."
            case .nameTaken: "Another session already has this name."
            case .noElements: "Add at least one timer."
            case .emptyLoop: "This loop needs at least one timer."
            }
        }
    }

    /// The issues to fix before saving; empty when the draft can be saved.
    /// - Parameter otherNames: The names of the other sessions, without the one being edited.
    func issues(otherNames: [String]) -> [Issue] {
        var issues: [Issue] = []
        if SessionNaming.normalized(name).isEmpty {
            issues.append(.noName)
        } else if SessionNaming.isTaken(name, by: otherNames) {
            issues.append(.nameTaken)
        }
        if elements.isEmpty {
            issues.append(.noElements)
        }
        for case .loop(let loop) in elements where loop.steps.isEmpty {
            issues.append(.emptyLoop(loop.id))
        }
        return issues
    }

    // MARK: - Adding and changing

    /// Appends `step` to the loop with `loopID`, or to the session when it is `nil`.
    mutating func add(_ step: SessionStep, toLoop loopID: UUID? = nil) {
        if let loopID {
            updateLoop(loopID) { $0.steps.append(step) }
        } else {
            elements.append(.step(step))
        }
    }

    /// Appends an empty loop and returns its id.
    @discardableResult
    mutating func addLoop() -> UUID {
        let loop = SessionLoop()
        elements.append(.loop(loop))
        return loop.id
    }

    /// Replaces the step that has `step`'s id, wherever it is.
    mutating func update(_ step: SessionStep) {
        for index in elements.indices {
            switch elements[index] {
            case .step(let existing) where existing.id == step.id:
                elements[index] = .step(step)
            case .loop(var loop):
                if let stepIndex = loop.steps.firstIndex(where: { $0.id == step.id }) {
                    loop.steps[stepIndex] = step
                    elements[index] = .loop(loop)
                }
            default:
                break
            }
        }
    }

    /// Sets a loop's rounds and rest, kept within their limits.
    mutating func setLoop(_ loopID: UUID, rounds: Int, restSeconds: Int) {
        updateLoop(loopID) { loop in
            let range = SessionLoop.roundsRange
            loop.rounds = min(max(rounds, range.lowerBound), range.upperBound)
            loop.restSeconds = min(max(restSeconds, 0), SessionLoop.maximumRestSeconds)
        }
    }

    /// Removes the step or loop with `id`, wherever it is. A loop goes with its steps.
    mutating func remove(_ id: UUID) {
        elements.removeAll { $0.id == id }
        for index in elements.indices {
            if case .loop(var loop) = elements[index] {
                loop.steps.removeAll { $0.id == id }
                elements[index] = .loop(loop)
            }
        }
    }

    // MARK: - Reordering

    /// Where a block lives: among the session's elements, or among a loop's steps.
    enum Level: Equatable {
        case session
        case loop(UUID)
    }

    func level(of id: UUID) -> Level? {
        if elements.contains(where: { $0.id == id }) {
            return .session
        }
        for case .loop(let loop) in elements where loop.steps.contains(where: { $0.id == id }) {
            return .loop(loop.id)
        }
        return nil
    }

    /// A place a dragged block can be dropped at: the gap before or after another block,
    /// or the end of a loop (which is also the way into an empty one).
    enum Place: Equatable {
        case before(UUID)
        case after(UUID)
        case endOfLoop(UUID)
    }

    /// The place the block `id` really goes to when dropped at `place`. A timer goes
    /// anywhere (extension 3d). A loop can't go into a loop: aimed at a place inside one,
    /// it goes before or after that loop instead.
    func resolved(_ place: Place, for id: UUID) -> Place {
        guard step(id) == nil else { return place }
        switch place {
        case .before(let targetID):
            if case .loop(let loopID) = level(of: targetID) { return .before(loopID) }
        case .after(let targetID):
            if case .loop(let loopID) = level(of: targetID) { return .after(loopID) }
        case .endOfLoop(let loopID):
            return .after(loopID)
        }
        return place
    }

    /// Moves the block `id` to `place`, taking it out of wherever it was.
    mutating func drop(_ id: UUID, at place: Place) {
        let place = resolved(place, for: id)
        // Everything is checked before the block is taken out, so a drop that can't be
        // done never loses the block.
        guard let element = elements.first(where: { $0.id == id }) ?? step(id).map(SessionElement.step) else { return }

        switch place {
        case .before(let targetID), .after(let targetID):
            guard id != targetID, let targetLevel = level(of: targetID) else { return }
            let offset = place == .after(targetID) ? 1 : 0
            switch targetLevel {
            case .session:
                remove(id)
                if let index = elements.firstIndex(where: { $0.id == targetID }) {
                    elements.insert(element, at: index + offset)
                }
            case .loop(let loopID):
                guard case .step(let step) = element else { return }
                remove(id)
                updateLoop(loopID) { loop in
                    if let index = loop.steps.firstIndex(where: { $0.id == targetID }) {
                        loop.steps.insert(step, at: index + offset)
                    }
                }
            }
        case .endOfLoop(let loopID):
            guard case .step(let step) = element, level(of: loopID) == .session else { return }
            remove(id)
            updateLoop(loopID) { $0.steps.append(step) }
        }
    }

    /// Whether dropping the block there changes anything, for showing where it would land.
    func canDrop(_ id: UUID, at place: Place) -> Bool {
        var copy = self
        copy.drop(id, at: place)
        return copy != self
    }

    /// A move between a loop and the session, for timers that are in a loop or next to one.
    enum LoopMove: Equatable {
        case intoLoopAbove
        case intoLoopBelow
        case outOfLoop
    }

    /// The loop moves open to the block `id`: out of its loop for a loop's timer; into
    /// the loop directly above or below for a session's timer. None for a loop.
    func loopMoves(for id: UUID) -> [LoopMove] {
        guard step(id) != nil else { return [] }
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return [.outOfLoop] }
        var moves: [LoopMove] = []
        if index > 0, elements[index - 1].loopValue != nil {
            moves.append(.intoLoopAbove)
        }
        if index + 1 < elements.count, elements[index + 1].loopValue != nil {
            moves.append(.intoLoopBelow)
        }
        return moves
    }

    /// Applies a loop move. Going in, the timer keeps its place in the running order: it
    /// becomes the last timer of the loop above, or the first of the loop below. Going
    /// out, a loop's first timer lands above the loop and any other below it.
    mutating func move(_ id: UUID, _ loopMove: LoopMove) {
        guard loopMoves(for: id).contains(loopMove) else { return }
        switch loopMove {
        case .intoLoopAbove:
            guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
            drop(id, at: .endOfLoop(elements[index - 1].id))
        case .intoLoopBelow:
            guard let index = elements.firstIndex(where: { $0.id == id }),
                  let loop = elements[index + 1].loopValue else { return }
            drop(id, at: loop.steps.first.map { .before($0.id) } ?? .endOfLoop(loop.id))
        case .outOfLoop:
            guard case .loop(let loopID) = level(of: id),
                  let loop = elements.first(where: { $0.id == loopID })?.loopValue else { return }
            drop(id, at: loop.steps.first?.id == id ? .before(loopID) : .after(loopID))
        }
    }

    /// The timer with `id`, on either level; `nil` for a loop.
    private func step(_ id: UUID) -> SessionStep? {
        for element in elements {
            switch element {
            case .step(let step) where step.id == id:
                return step
            case .loop(let loop):
                if let step = loop.steps.first(where: { $0.id == id }) {
                    return step
                }
            default:
                break
            }
        }
        return nil
    }

    /// Moves the block `id` one place up (`offset` −1) or down (+1) within its level.
    mutating func move(_ id: UUID, by offset: Int) {
        guard let level = level(of: id) else { return }
        switch level {
        case .session:
            Self.move(id, by: offset, in: &elements)
        case .loop(let loopID):
            updateLoop(loopID) { Self.move(id, by: offset, in: &$0.steps) }
        }
    }

    /// Whether the block can move in that direction, for enabling the menu items.
    func canMove(_ id: UUID, by offset: Int) -> Bool {
        var copy = self
        copy.move(id, by: offset)
        return copy != self
    }

    private static func move<Item: Identifiable>(_ id: UUID, by offset: Int, in items: inout [Item])
    where Item.ID == UUID {
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard items.indices.contains(to) else { return }
        items.swapAt(from, to)
    }

    private mutating func updateLoop(_ loopID: UUID, _ change: (inout SessionLoop) -> Void) {
        guard let index = elements.firstIndex(where: { $0.id == loopID }),
              case .loop(var loop) = elements[index] else { return }
        change(&loop)
        elements[index] = .loop(loop)
    }

    // MARK: - Saving

    /// Writes the draft to `existingSession`, or inserts a new session. The name is
    /// stored without surrounding whitespace.
    @MainActor
    func save(editing existingSession: TrainingSession?, in modelContext: ModelContext) {
        let storedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // The edited session can be gone by now: deleted on another device while the
        // editor was open. Writing to a deleted model is an error, so the draft is then
        // stored as a new session and the athlete's work isn't lost.
        if let existingSession, existingSession.modelContext != nil, !existingSession.isDeleted {
            existingSession.name = storedName
            existingSession.elements = elements
        } else {
            modelContext.insert(TrainingSession(name: storedName, elements: elements))
        }
    }
}

private extension SessionElement {
    /// The loop, when the element is one.
    var loopValue: SessionLoop? {
        if case .loop(let loop) = self { loop } else { nil }
    }
}
