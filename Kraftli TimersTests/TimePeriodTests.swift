//
//  TimePeriodTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct TimePeriodTests {

    // MARK: - Display Name Tests

    @Test func displayName_week_returnsWeek() {
        #expect(TimePeriod.week.displayName == "Week")
    }

    @Test func displayName_month_returnsMonth() {
        #expect(TimePeriod.month.displayName == "Month")
    }

    @Test func displayName_year_returnsYear() {
        #expect(TimePeriod.year.displayName == "Year")
    }

    // MARK: - Date Range Tests

    @Test func dateRange_week_returnsCurrentWeekBoundaries() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.week.dateRange(from: today)

        // Start should be at the beginning of the week
        let weekdayOfStart = calendar.component(.weekday, from: range.start)
        let firstWeekday = calendar.firstWeekday
        #expect(weekdayOfStart == firstWeekday)

        // End should be after start
        #expect(range.end > range.start)

        // Today should be within the range
        #expect(today >= range.start)
        #expect(today <= range.end)
    }

    @Test func dateRange_month_returnsCurrentMonthBoundaries() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.month.dateRange(from: today)

        // Start should be day 1
        let dayOfStart = calendar.component(.day, from: range.start)
        #expect(dayOfStart == 1)

        // Start and end should be in the same month
        let monthOfStart = calendar.component(.month, from: range.start)
        let monthOfEnd = calendar.component(.month, from: range.end)
        #expect(monthOfStart == monthOfEnd)

        // Today should be within the range
        #expect(today >= range.start)
        #expect(today <= range.end)
    }

    @Test func dateRange_year_returnsCurrentYearBoundaries() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.year.dateRange(from: today)

        // Start should be January 1
        let monthOfStart = calendar.component(.month, from: range.start)
        let dayOfStart = calendar.component(.day, from: range.start)
        #expect(monthOfStart == 1)
        #expect(dayOfStart == 1)

        // End should be December 31
        let monthOfEnd = calendar.component(.month, from: range.end)
        #expect(monthOfEnd == 12)

        // Same year
        let yearOfStart = calendar.component(.year, from: range.start)
        let yearOfEnd = calendar.component(.year, from: range.end)
        #expect(yearOfStart == yearOfEnd)

        // Today should be within the range
        #expect(today >= range.start)
        #expect(today <= range.end)
    }

    @Test func dateRange_withSpecificDate_returnsCorrectBoundaries() {
        let calendar = Calendar.current

        // Create a specific date: January 15, 2026
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = calendar.date(from: components)!

        let range = TimePeriod.month.dateRange(from: date)

        // Should start on January 1
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        #expect(startComponents.year == 2026)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 1)

        // Should end on January 31
        let endComponents = calendar.dateComponents([.day], from: range.end)
        #expect(endComponents.day == 31)
    }

    // MARK: - Chart Data Points Tests

    @Test func chartDataPoints_week_returns7() {
        #expect(TimePeriod.week.chartDataPoints == 7)
    }

    @Test func chartDataPoints_month_returns30() {
        #expect(TimePeriod.month.chartDataPoints == 30)
    }

    @Test func chartDataPoints_year_returns12() {
        #expect(TimePeriod.year.chartDataPoints == 12)
    }

    // MARK: - Chart Grouping Tests

    @Test func chartGrouping_week_isDay() {
        #expect(TimePeriod.week.chartGrouping == .day)
    }

    @Test func chartGrouping_month_isDay() {
        #expect(TimePeriod.month.chartGrouping == .day)
    }

    @Test func chartGrouping_year_isMonth() {
        #expect(TimePeriod.year.chartGrouping == .month)
    }

    // MARK: - Identifiable Tests

    @Test func id_isRawValue() {
        #expect(TimePeriod.week.id == "week")
        #expect(TimePeriod.month.id == "month")
        #expect(TimePeriod.year.id == "year")
    }

    // MARK: - CaseIterable Tests

    @Test func allCases_containsAllPeriods() {
        let allCases = TimePeriod.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.week))
        #expect(allCases.contains(.month))
        #expect(allCases.contains(.year))
    }
}
