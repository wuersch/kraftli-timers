//
//  BucketUnit.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 13.01.2026.
//
import Foundation

enum BucketUnit {
    case day
    case week
    case month
    case quarter
    
    func advance(
        _ date: Date,
        calendar: Calendar = .current
    ) -> Date {
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: date)!
        case .week:
            return calendar.date(byAdding: .day, value: 7, to: date)!
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date)!
        case .quarter:
            return calendar.date(byAdding: .month, value: 3, to: date)!
        }
    }
    
    func normalizedStart(
        _ date: Date,
        calendar: Calendar = .current
    ) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)

        case .week:
            return calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            )!

        case .month:
            return calendar.date(
                from: calendar.dateComponents([.year, .month], from: date)
            )!

        case .quarter:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let quarterStartMonth = ((comps.month! - 1) / 3) * 3 + 1
            return calendar.date(
                from: DateComponents(year: comps.year, month: quarterStartMonth)
            )!
        }
    }
}
