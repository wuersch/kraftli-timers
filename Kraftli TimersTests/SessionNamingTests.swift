//
//  SessionNamingTests.swift
//  Kraftli TimersTests
//
//  Session names: comparing them and naming a copy (UC-0013).
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct SessionNamingTests {
    @Test func names_compareTrimmedAndWithoutRegardToCase() {
        #expect(SessionNaming.isTaken(" legs ", by: ["Legs"]))
        #expect(SessionNaming.isTaken("LEGS", by: ["Upper Body", "legs"]))
        #expect(!SessionNaming.isTaken("Legs", by: ["Legs & Core"]))
    }

    @Test func copy_getsTheFirstFreeNumber() {
        #expect(SessionNaming.copyName(of: "Legs", existing: ["Legs"]) == "Legs 2")
        #expect(SessionNaming.copyName(of: "Legs", existing: ["Legs", "Legs 2", "legs 3"]) == "Legs 4")
    }

    @Test func copyOfACopy_countsOn_insteadOfStackingNumbers() {
        #expect(SessionNaming.copyName(of: "Legs 2", existing: ["Legs", "Legs 2"]) == "Legs 3")
    }

    @Test func nameThatIsOnlyANumber_isKeptAsTheBase() {
        #expect(SessionNaming.copyName(of: "100", existing: ["100"]) == "100 2")
    }
}
