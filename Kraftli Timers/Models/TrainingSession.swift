//
//  TrainingSession.swift
//  Kraftli Timers
//
//  SwiftData model for a training session (UC-0013).
//

import Foundation
import SwiftData

/// A named, reusable training: an ordered sequence of steps and loops.
///
/// The elements aren't SwiftData models of their own. The session stores them as one
/// encoded document, because a session is always edited and saved as a whole, and
/// CloudKit has no ordered relationships (ADR-0011).
@Model
final class TrainingSession {
    // CloudKit requires default values for all non-optional attributes
    var id: UUID = UUID()
    var name: String = ""
    /// A `SessionDocument` as JSON. Read and written through `elements`.
    var elementsData: Data?

    /// The session's steps and loops, in running order. A computed property isn't
    /// persisted: SwiftData only stores `elementsData`.
    var elements: [SessionElement] {
        get { SessionDocument.elements(from: elementsData) }
        set { elementsData = SessionDocument.data(for: newValue) }
    }

    init(id: UUID = UUID(), name: String, elements: [SessionElement] = []) {
        self.id = id
        self.name = name
        self.elementsData = SessionDocument.data(for: elements)
    }
}
