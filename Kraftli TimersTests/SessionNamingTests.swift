//
//  SessionNamingTests.swift
//  Kraftli TimersTests
//
//  Session names (UC-0013) and the weekday order of the plan (UC-0014).
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

struct WeekLayoutTests {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func week_startsWithTheRegionsFirstWeekday() {
        #expect(WeekLayout.orderedWeekdays(calendar: calendar(firstWeekday: 2)) == [2, 3, 4, 5, 6, 7, 1])
        #expect(WeekLayout.orderedWeekdays(calendar: calendar(firstWeekday: 1)) == [1, 2, 3, 4, 5, 6, 7])
        #expect(WeekLayout.orderedWeekdays(calendar: calendar(firstWeekday: 7)) == [7, 1, 2, 3, 4, 5, 6])
    }

    @Test func weekday_ofADate_usesTheCalendarsNumbering() {
        // 17 November 2026 is a Tuesday: weekday 3.
        let tuesday = Date(timeIntervalSince1970: 1_794_916_800)
        let calendar = calendar(firstWeekday: 2)

        #expect(WeekLayout.weekday(of: tuesday, calendar: calendar) == 3)
        #expect(WeekLayout.shortName(of: 3, calendar: calendar) == "Tue")
        #expect(WeekLayout.name(of: 3, calendar: calendar) == "Tuesday")
    }
}
