//
//  TimePeriodTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct TimePeriodTests {

    // MARK: - Display Name Tests

    @Test func displayName_week_returns7Days() {
        #expect(TimePeriod.week.displayName == "7 Days")
    }

    @Test func displayName_month_returnsMonth() {
        #expect(TimePeriod.month.displayName == "Month")
    }

    @Test func displayName_sixMonths_returns6Months() {
        #expect(TimePeriod.sixMonths.displayName == "6 Months")
    }

    @Test func displayName_year_returnsYear() {
        #expect(TimePeriod.year.displayName == "Year")
    }

    // MARK: - Summary Unit Tests

    @Test func summaryUnit_week_returnsLast7Days() {
        #expect(TimePeriod.week.summaryUnit == "last 7 days")
    }

    @Test func summaryUnit_month_returnsLast4Weeks() {
        #expect(TimePeriod.month.summaryUnit == "last 4 weeks")
    }

    @Test func summaryUnit_sixMonths_returnsLast6Months() {
        #expect(TimePeriod.sixMonths.summaryUnit == "last 6 months")
    }

    @Test func summaryUnit_year_returnsLast12Months() {
        #expect(TimePeriod.year.summaryUnit == "last 12 months")
    }

    // MARK: - Date Range Tests (Sliding Window)

    @Test func dateRange_week_returnsLast7Days() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.week.dateRange(from: today)

        // End should be today
        #expect(range.end == today)

        // Start should be 6 days before today (inclusive = 7 days total)
        let expectedStart = calendar.date(byAdding: .day, value: -6, to: today)!
        #expect(range.start == expectedStart)

        // Verify total span is 7 days
        let daysDiff = calendar.dateComponents([.day], from: range.start, to: range.end).day
        #expect(daysDiff == 6) // 0-indexed: day 0 to day 6 = 7 days total
    }

    @Test func dateRange_month_returnsLast28Days() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.month.dateRange(from: today)

        // End should be today
        #expect(range.end == today)

        // Start should be 27 days before today (inclusive = 28 days total)
        let expectedStart = calendar.date(byAdding: .day, value: -27, to: today)!
        #expect(range.start == expectedStart)

        // Verify total span is approximately 28 days
        let daysDiff = calendar.dateComponents([.day], from: range.start, to: range.end).day
        #expect(daysDiff == 27) // 0-indexed: 28 days total
    }

    @Test func dateRange_sixMonths_returnsLast6Months() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.sixMonths.dateRange(from: today)

        // End should be today
        #expect(range.end == today)

        // Start should be 6 months before today
        let expectedStart = calendar.date(byAdding: .month, value: -6, to: today)!
        #expect(range.start == expectedStart)
    }

    @Test func dateRange_year_returnsLast12Months() {
        let calendar = Calendar.current
        let today = Date()
        let range = TimePeriod.year.dateRange(from: today)

        // End should be today
        #expect(range.end == today)

        // Start should be 11 months before today
        let expectedStart = calendar.date(byAdding: .month, value: -11, to: today)!
        #expect(range.start == expectedStart)
    }

    @Test func dateRange_withSpecificDate_usesCorrectReferenceDate() {
        let calendar = Calendar.current

        // Create a specific date: January 15, 2026
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let referenceDate = calendar.date(from: components)!

        let range = TimePeriod.month.dateRange(from: referenceDate)

        // End should be the reference date
        #expect(range.end == referenceDate)

        // Start should be 27 days before reference date
        let expectedStart = calendar.date(byAdding: .day, value: -27, to: referenceDate)!
        #expect(range.start == expectedStart)
    }

    // MARK: - Bucket Unit Tests

    @Test func bucketUnit_week_isDay() {
        #expect(TimePeriod.week.bucketUnit == .day)
    }

    @Test func bucketUnit_month_isDay() {
        #expect(TimePeriod.month.bucketUnit == .day)
    }

    @Test func bucketUnit_sixMonths_isMonth() {
        #expect(TimePeriod.sixMonths.bucketUnit == .month)
    }

    @Test func bucketUnit_year_isMonth() {
        #expect(TimePeriod.year.bucketUnit == .month)
    }

    // MARK: - All Buckets Tests

    @Test func allBuckets_week_generates7DailyBuckets() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let buckets = TimePeriod.week.allBuckets(referenceDate: today)

        // Should have 7 or 8 buckets (depending on time of day)
        #expect(buckets.count >= 7)
        #expect(buckets.count <= 8)

        // First bucket should be normalized to start of day
        let firstBucket = buckets.first!
        let startOfFirstBucket = calendar.startOfDay(for: firstBucket)
        #expect(firstBucket == startOfFirstBucket)
    }

    @Test func allBuckets_month_generates28DailyBuckets() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let buckets = TimePeriod.month.allBuckets(referenceDate: today)

        // Should have approximately 28-29 daily buckets
        #expect(buckets.count >= 28)
        #expect(buckets.count <= 29)
    }

    @Test func allBuckets_sixMonths_generatesMonthlyBuckets() {
        let today = Date()

        let buckets = TimePeriod.sixMonths.allBuckets(referenceDate: today)

        // Should have approximately 6-7 monthly buckets
        #expect(buckets.count >= 6)
        #expect(buckets.count <= 7)
    }

    @Test func allBuckets_year_generatesMonthlyBuckets() {
        let today = Date()

        let buckets = TimePeriod.year.allBuckets(referenceDate: today)

        // Should have 12 or 13 monthly buckets
        #expect(buckets.count >= 12)
        #expect(buckets.count <= 13)
    }

    // MARK: - Identifiable Tests

    @Test func id_isRawValue() {
        #expect(TimePeriod.week.id == "week")
        #expect(TimePeriod.month.id == "month")
        #expect(TimePeriod.sixMonths.id == "sixMonths")
        #expect(TimePeriod.year.id == "year")
    }

    // MARK: - CaseIterable Tests

    @Test func allCases_containsAllPeriods() {
        let allCases = TimePeriod.allCases

        #expect(allCases.count == 4)
        #expect(allCases.contains(.week))
        #expect(allCases.contains(.month))
        #expect(allCases.contains(.sixMonths))
        #expect(allCases.contains(.year))
    }

    // MARK: - Selectable Cases Tests

    @Test func selectableCases_containsAllPeriods() {
        let selectableCases = TimePeriod.selectableCases

        #expect(selectableCases.count == 4)
        #expect(selectableCases.contains(.week))
        #expect(selectableCases.contains(.month))
        #expect(selectableCases.contains(.sixMonths))
        #expect(selectableCases.contains(.year))
    }
}
