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
    /// Blocks are only reordered within their level.
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

    /// Moves the block `id` to the place of the block `targetID`, as dropping one on the
    /// other does. Does nothing when the two aren't on the same level.
    mutating func move(_ id: UUID, onto targetID: UUID) {
        guard id != targetID, let level = level(of: id), level == self.level(of: targetID) else { return }
        switch level {
        case .session:
            Self.move(id, onto: targetID, in: &elements)
        case .loop(let loopID):
            updateLoop(loopID) { Self.move(id, onto: targetID, in: &$0.steps) }
        }
    }

    /// Handles a block dropped on another. On the same level it takes the other's place.
    /// A session block dropped on a timer inside a loop takes the place of that loop,
    /// so the whole loop is a drop target for the blocks around it.
    mutating func drop(_ id: UUID, onto targetID: UUID) {
        if level(of: id) == .session, case .loop(let loopID) = level(of: targetID) {
            move(id, onto: loopID)
        } else {
            move(id, onto: targetID)
        }
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

    private static func move<Item: Identifiable>(_ id: UUID, onto targetID: UUID, in items: inout [Item])
    where Item.ID == UUID {
        guard let from = items.firstIndex(where: { $0.id == id }),
              let to = items.firstIndex(where: { $0.id == targetID }) else { return }
        // Taking the block out first shifts everything after it up by one, so inserting at
        // the target's old index puts it after the target when moving down, before it when
        // moving up: in both cases where the target was.
        let item = items.remove(at: from)
        items.insert(item, at: to)
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
        if let existingSession {
            existingSession.name = storedName
            existingSession.elements = elements
        } else {
            modelContext.insert(TrainingSession(name: storedName, elements: elements))
        }
    }
}
