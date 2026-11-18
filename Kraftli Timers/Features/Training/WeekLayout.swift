//
//  WeekLayout.swift
//  Kraftli Timers
//
//  The order and names of the weekdays in the week plan (UC-0014).
//

import Foundation

/// Weekdays are numbered as `Calendar` numbers them: 1 = Sunday … 7 = Saturday. That
/// number is what the plan stores; the order they are shown in depends on the region.
///
/// The calendar and the date are parameters so tests can pass fixed ones.
enum WeekLayout {
    /// The seven weekdays, starting with the first weekday of the calendar's region:
    /// Monday in Switzerland, Sunday in the US.
    static func orderedWeekdays(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    static func weekday(of date: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// "Mon"
    static func shortName(of weekday: Int, calendar: Calendar = .current) -> String {
        calendar.shortWeekdaySymbols[weekday - 1]
    }

    /// "Monday"
    static func name(of weekday: Int, calendar: Calendar = .current) -> String {
        calendar.weekdaySymbols[weekday - 1]
    }
}
