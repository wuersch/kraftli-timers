//
//  TimePeriod.swift
//  Kraftli Timers
//
//  Time period options for filtering workout statistics.
//

import Foundation

/// Time periods for filtering and grouping workout statistics.
enum TimePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// Calculates the date range for this period ending at the reference date.
    ///
    /// - Parameter referenceDate: The end date of the range (typically today).
    /// - Returns: A tuple containing the start and end dates of the period.
    func dateRange(from referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: referenceDate).addingTimeInterval(86400 - 1)

        let startDate: Date
        switch self {
        case .week:
            // Last 7 days including today
            startDate = calendar.startOfDay(for: referenceDate.addingTimeInterval(-6 * 86400))
        case .month:
            // Last 30 days including today
            startDate = calendar.startOfDay(for: referenceDate.addingTimeInterval(-29 * 86400))
        case .year:
            // Last 365 days including today
            startDate = calendar.startOfDay(for: referenceDate.addingTimeInterval(-364 * 86400))
        }

        return (start: startDate, end: endOfDay)
    }

    /// Number of data points to show in charts for this period.
    var chartDataPoints: Int {
        switch self {
        case .week: return 7      // Daily bars
        case .month: return 30    // Daily bars
        case .year: return 12     // Monthly bars
        }
    }

    /// The grouping granularity for chart data.
    var chartGrouping: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .day
        case .year: return .month
        }
    }
}
