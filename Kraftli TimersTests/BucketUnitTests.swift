//
//  BucketUnitTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct BucketUnitTests {

    // MARK: - advance() Tests

    @Test func advance_day_adds1Day() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 10
        let date = calendar.date(from: components)!

        let nextDay = BucketUnit.day.advance(date, calendar: calendar)

        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
        #expect(nextComponents.year == 2026)
        #expect(nextComponents.month == 1)
        #expect(nextComponents.day == 16)
    }

    @Test func advance_week_adds7Days() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = calendar.date(from: components)!

        let nextWeek = BucketUnit.week.advance(date, calendar: calendar)

        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextWeek)
        #expect(nextComponents.year == 2026)
        #expect(nextComponents.month == 1)
        #expect(nextComponents.day == 22)
    }

    @Test func advance_month_adds1Month() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = calendar.date(from: components)!

        let nextMonth = BucketUnit.month.advance(date, calendar: calendar)

        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextMonth)
        #expect(nextComponents.year == 2026)
        #expect(nextComponents.month == 2)
        #expect(nextComponents.day == 15)
    }

    @Test func advance_quarter_adds3Months() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = calendar.date(from: components)!

        let nextQuarter = BucketUnit.quarter.advance(date, calendar: calendar)

        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextQuarter)
        #expect(nextComponents.year == 2026)
        #expect(nextComponents.month == 4)
        #expect(nextComponents.day == 15)
    }

    @Test func advance_quarter_crossesYearBoundary() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 11
        components.day = 15
        let date = calendar.date(from: components)!

        let nextQuarter = BucketUnit.quarter.advance(date, calendar: calendar)

        let nextComponents = calendar.dateComponents([.year, .month], from: nextQuarter)
        #expect(nextComponents.year == 2026)
        #expect(nextComponents.month == 2)
    }

    // MARK: - normalizedStart() Tests - Day

    @Test func normalizedStart_day_returnsStartOfDay() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30
        components.second = 45
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.day.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 1)
        #expect(normalizedComponents.day == 15)
        #expect(normalizedComponents.hour == 0)
        #expect(normalizedComponents.minute == 0)
        #expect(normalizedComponents.second == 0)
    }

    // MARK: - normalizedStart() Tests - Week

    @Test func normalizedStart_week_returnsStartOfWeek() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15 // Wednesday
        components.hour = 14
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.week.normalizedStart(date, calendar: calendar)

        // Should return the start of the week containing Jan 15
        // Verify that it's using yearForWeekOfYear and weekOfYear
        let normalizedComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: normalized)
        let originalComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)

        #expect(normalizedComponents.yearForWeekOfYear == originalComponents.yearForWeekOfYear)
        #expect(normalizedComponents.weekOfYear == originalComponents.weekOfYear)
    }

    @Test func normalizedStart_week_resultsInSameWeek() {
        let calendar = Calendar.current
        let today = Date()

        let normalized = BucketUnit.week.normalizedStart(today, calendar: calendar)

        // Verify that the normalized date is in the same week as today
        let todayWeek = calendar.component(.weekOfYear, from: today)
        let normalizedWeek = calendar.component(.weekOfYear, from: normalized)

        #expect(normalizedWeek == todayWeek)
    }

    // MARK: - normalizedStart() Tests - Month

    @Test func normalizedStart_month_returnsStartOfMonth() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 14
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.month.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 1)
        #expect(normalizedComponents.day == 1)
        #expect(normalizedComponents.hour == 0)
        #expect(normalizedComponents.minute == 0)
    }

    // MARK: - normalizedStart() Tests - Quarter

    @Test func normalizedStart_quarter_january_returnsJanuary1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 1)
        #expect(normalizedComponents.day == 1)
    }

    @Test func normalizedStart_quarter_february_returnsJanuary1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 1)
        #expect(normalizedComponents.day == 1)
    }

    @Test func normalizedStart_quarter_march_returnsJanuary1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 1)
        #expect(normalizedComponents.day == 1)
    }

    @Test func normalizedStart_quarter_april_returnsApril1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 4)
        #expect(normalizedComponents.day == 1)
    }

    @Test func normalizedStart_quarter_july_returnsJuly1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 7)
        #expect(normalizedComponents.day == 1)
    }

    @Test func normalizedStart_quarter_october_returnsOctober1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 10)
        #expect(normalizedComponents.day == 1)
    }

    @Test func normalizedStart_quarter_december_returnsOctober1() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 12
        components.day = 15
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month, .day], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 10)
        #expect(normalizedComponents.day == 1)
    }

    // MARK: - Quarter Edge Cases

    @Test func normalizedStart_quarter_boundaryMonth1_returnsJanuary() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 1)
    }

    @Test func normalizedStart_quarter_boundaryMonth4_returnsApril() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 1
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 4)
    }

    @Test func normalizedStart_quarter_boundaryMonth7_returnsJuly() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 1
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 7)
    }

    @Test func normalizedStart_quarter_boundaryMonth10_returnsOctober() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        let date = calendar.date(from: components)!

        let normalized = BucketUnit.quarter.normalizedStart(date, calendar: calendar)

        let normalizedComponents = calendar.dateComponents([.year, .month], from: normalized)
        #expect(normalizedComponents.year == 2026)
        #expect(normalizedComponents.month == 10)
    }
}
