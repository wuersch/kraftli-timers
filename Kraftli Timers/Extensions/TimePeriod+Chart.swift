//
//  TimePeriod+Chart.swift
//  Kraftli Timers
//
//  Chart-specific extensions for TimePeriod.
//

import Foundation

extension TimePeriod {
    /// The calendar component to use for chart x-axis grouping.
    var chartUnit: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .day
        case .sixMonths: return .weekOfYear
        case .year: return .month
        }
    }
}
