//
//  TimePeriod.swift
//  Kraftli Timers
//
//  Time period options for filtering workout statistics.
//

import Foundation

/// Time periods for filtering and grouping workout statistics.
enum TimePeriod: String, CaseIterable, Identifiable {
    // MARK: - Cases
    case week          // bucket: day
    case month         // bucket: day
    case sixMonths     // bucket: month, chartUnit: week
    case year          // bucket: month

    // MARK: - Static (UI / selection)
    /// UI-scoped case list, in case internal time periods are added later
    static var selectableCases: [TimePeriod] {
        [.week, .month, .sixMonths, .year]
    }

    // MARK: - Identity
    var id: String { rawValue }

    // MARK: - UI-facing labels
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .sixMonths: return "6 Months"
        case .year: return "Year"
        }
    }
    
    var summaryUnit: String {
        switch self {
        case .week: return "last 7 days"
        case .month: return "last 4 weeks"
        case .sixMonths: return "last 6 months"
        case .year: return "last 12 months"
        }
    }

    // MARK: - Core semantics
    /// Calculates a sliding date range ending at referenceDate.
    ///
    /// - Parameter referenceDate: Typically today.
    /// - Returns: Start and end of the period.
    func dateRange(from referenceDate: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let end = referenceDate
        let start: Date

        switch self {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: end) ?? end // last 7 days
        case .month:
            start = calendar.date(byAdding: .day, value: -27, to: end) ?? end // last 28 days (~4 weeks)
        case .sixMonths:
            start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        case .year:
            start = calendar.date(byAdding: .month, value: -11, to: end) ?? end
        }

        return (start, end)
    }

    // MARK: - Bucketing semantics
    var bucketUnit: BucketUnit {
        switch self {
        case .week: return .day
        case .month: return .day
        case .sixMonths: return .month
        case .year: return .month
        }
    }
    
    func allBuckets(referenceDate: Date = .now) -> [Date] {
        let range = dateRange(from: referenceDate)
        let unit = bucketUnit
        var buckets: [Date] = []
        var current = unit.normalizedStart(range.start)
        while current <= range.end {
            buckets.append(current)
            current = unit.advance(current)
        }
        return buckets
    }
}
