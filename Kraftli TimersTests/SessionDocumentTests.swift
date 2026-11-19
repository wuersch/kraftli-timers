//
//  SessionDocumentTests.swift
//  Kraftli TimersTests
//
//  The stored format of a session's elements (ADR-0011).
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct SessionDocumentTests {
    @Test func elements_surviveARoundTrip() {
        let step = SessionStep(kind: .forTime, exerciseId: UUID(), durationInterval: 0, targetReps: 30)
        let loop = SessionLoop(rounds: 3, restSeconds: 60, steps: [step])
        let elements: [SessionElement] = [.step(step), .loop(loop)]

        #expect(SessionDocument.elements(from: SessionDocument.data(for: elements)) == elements)
    }

    @Test func missingOrUnreadableData_givesNoElements() {
        #expect(SessionDocument.elements(from: nil).isEmpty)
        #expect(SessionDocument.elements(from: Data("not json".utf8)).isEmpty)
    }

    /// A newer app version may add fields; this one must still read the rest.
    @Test func unknownFields_areIgnored() {
        let json = """
        {"version":2,"note":"x","elements":[{"step":{"id":"\(UUID().uuidString)","kindRawValue":"AMRAP",\
        "durationInterval":300,"colour":"red"}}]}
        """

        let elements = SessionDocument.elements(from: Data(json.utf8))

        #expect(elements.count == 1)
        guard case .step(let step) = elements.first else {
            Issue.record("expected a step")
            return
        }
        #expect(step.kind == .amrap)
        #expect(step.targetReps == nil)
    }
}
