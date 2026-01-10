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

    /// Calculates the date range for this period based on calendar boundaries.
    ///
    /// - Parameter referenceDate: The reference date (typically today).
    /// - Returns: A tuple containing the start and end dates of the period.
    func dateRange(from referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current

        switch self {
        case .week:
            // Current calendar week (Monday to Sunday)
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
                return (referenceDate, referenceDate)
            }
            return (start: weekInterval.start, end: weekInterval.end.addingTimeInterval(-1))

        case .month:
            // Current calendar month
            guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) else {
                return (referenceDate, referenceDate)
            }
            return (start: monthInterval.start, end: monthInterval.end.addingTimeInterval(-1))

        case .year:
            // Current calendar year
            guard let yearInterval = calendar.dateInterval(of: .year, for: referenceDate) else {
                return (referenceDate, referenceDate)
            }
            return (start: yearInterval.start, end: yearInterval.end.addingTimeInterval(-1))
        }
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
