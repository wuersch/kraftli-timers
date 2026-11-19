//
//  WeekLayoutTests.swift
//  Kraftli TimersTests
//
//  The order and names of the weekdays in the week plan (UC-0014).
//

import Foundation
import Testing
@testable import Kraftli_Timers

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
