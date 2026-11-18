//
//  SessionElement.swift
//  Kraftli Timers
//
//  The building blocks of a training session (UC-0013): steps and loops.
//

import Foundation

/// One timer in a session: the same settings a preset has, in the form a preset
/// stores them.
///
/// A plain value type, not a SwiftData model: a session keeps all its elements as one
/// encoded value. `nonisolated` so the `Codable` conformance can be used off the main actor.
nonisolated struct SessionStep: Codable, Equatable, Identifiable, Sendable {
    /// Identifies the step within its session, for SwiftUI lists and for a later runner.
    var id: UUID = UUID()
    /// The kind as its raw value, so a kind this app version doesn't know still decodes.
    var kindRawValue: String
    var exerciseId: UUID?
    /// The timer's length in seconds; 0 for For Time, which has no duration (ADR-0010).
    var durationInterval: TimeInterval
    /// EMOM: total reps. For Time: the target. `nil` for AMRAP.
    var targetReps: Int?

    var kind: TimerKind {
        TimerKind(rawValue: kindRawValue) ?? .emom
    }

    init(
        id: UUID = UUID(),
        kind: TimerKind,
        exerciseId: UUID?,
        durationInterval: TimeInterval,
        targetReps: Int?
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.exerciseId = exerciseId
        self.durationInterval = durationInterval
        self.targetReps = targetReps
    }
}

/// Steps repeated a number of rounds, with an optional rest after each round except
/// the last. A loop holds steps only, so a loop can't contain a loop.
nonisolated struct SessionLoop: Codable, Equatable, Identifiable, Sendable {
    static let roundsRange = 2...20
    /// The longest rest between rounds, in seconds. 0 means no rest.
    static let maximumRestSeconds = 10 * 60

    var id: UUID = UUID()
    var rounds: Int = SessionLoop.roundsRange.lowerBound
    var restSeconds: Int = 0
    var steps: [SessionStep] = []
}

/// An element of a session: a single step, or a loop of steps.
nonisolated enum SessionElement: Equatable, Identifiable, Sendable {
    case step(SessionStep)
    case loop(SessionLoop)

    var id: UUID {
        switch self {
        case .step(let step): step.id
        case .loop(let loop): loop.id
        }
    }
}

// The synthesized enum coding would write `{"step":{"_0":{…}}}`. Writing it by hand
// gives the stored JSON a shape that doesn't depend on how the cases are declared.
nonisolated extension SessionElement: Codable {
    private enum CodingKeys: String, CodingKey {
        case step, loop
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let step = try container.decodeIfPresent(SessionStep.self, forKey: .step) {
            self = .step(step)
        } else {
            self = .loop(try container.decode(SessionLoop.self, forKey: .loop))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .step(let step): try container.encode(step, forKey: .step)
        case .loop(let loop): try container.encode(loop, forKey: .loop)
        }
    }
}

/// What a session record stores: its elements, wrapped with a format version so a later
/// app version can change the format and still read the old one.
nonisolated struct SessionDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int = SessionDocument.currentVersion
    var elements: [SessionElement] = []

    /// The elements stored in `data`; none if there is no data or it can't be read.
    static func elements(from data: Data?) -> [SessionElement] {
        guard let data, let document = try? JSONDecoder().decode(SessionDocument.self, from: data) else {
            return []
        }
        return document.elements
    }

    static func data(for elements: [SessionElement]) -> Data? {
        try? JSONEncoder().encode(SessionDocument(elements: elements))
    }
}
