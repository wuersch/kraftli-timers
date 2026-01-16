//
//  ActivityChart.swift
//  Kraftli Timers
//
//  Bar chart displaying workout activity over time.
//

import SwiftUI
import Charts

/// A bar chart showing workout minutes over a time period.
struct ActivityChart: View {
    let chartData: [ChartDataPoint]
    let selectedPeriod: TimePeriod
    let totalMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            Chart(chartData) { dataPoint in
                BarMark(
                    x: .value("Date", dataPoint.date, unit: selectedPeriod.chartUnit),
                    y: .value("Minutes", dataPoint.minutes),
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                if selectedPeriod == .month {
                    // Use automatic spacing for month (too many days to show all)
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(xAxisLabel(for: date))
                                    .font(.caption2)
                            }
                        }
                    }
                } else {
                    // Show all labels for week (7 days) and year (12 months)
                    AxisMarks(values: chartData.map { $0.date }) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(xAxisLabel(for: date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)m")
                        }
                    }
                }
            }
            .ifLet(paddedDomain()) { view, domain in
                view.chartXScale(domain: domain)
            }
            .frame(height: 200)
            .accessibilityLabel(accessibilityDescription)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Computes a padded x-domain so the last bucket isn't flush with the plot edges.
    private func paddedDomain() -> ClosedRange<Date>? {
        guard let minDate = chartData.map(\.date).min(),
              let maxDate = chartData.map(\.date).max() else {
            return nil
        }
        let calendar = Calendar.current
        switch selectedPeriod {
        case .sixMonths:
            // Small, consistent padding matching the unit (week)
            let upper = calendar.date(byAdding: .weekOfYear, value: 3, to: maxDate) ?? maxDate
            return minDate...upper
        default:
            // All other periods: no manual domain scaling
            return nil
        }
    }
    
    /// MARK: - Accessibility
    private var accessibilityDescription: String {
        "Activity chart: \(totalMinutes) total minutes in the \(periodName)."
    }
    
    // MARK: - Helpers

    /// Human-readable name for the selected period.
    private var periodName: String {
        switch selectedPeriod {
        case .week: return "last week"
        case .month: return "last month"
        case .sixMonths: return "last six months"
        case .year: return "last year"
        }
    }
    
    /// Formats date for x-axis labels based on the selected period.
    private func xAxisLabel(for date: Date) -> String {
        switch selectedPeriod {
        case .week:
            // Short weekday: Mon, Tue, Wed, etc.
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        case .month:
            return "\(Calendar.current.component(.day, from: date))" // numeric day
        case .sixMonths:
            // Three letter month: Jan, Feb, Mar, etc.
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        case .year:
            // Narrow month abbreviation (single letter): J, F, M, etc.
            // Note: "MMMMM" (5 M's) produces narrow month symbol per DateFormatter
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMMM"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    let today = Date()
    let calendar = Calendar.current

    let sampleData = (0..<7).map { offset in
        ChartDataPoint(
            date: calendar.date(byAdding: .day, value: -offset, to: today)!,
            minutes: Int.random(in: 0...45)
        )
    }.reversed()

    return ActivityChart(
        chartData: Array(sampleData),
        selectedPeriod: .week,
        totalMinutes: 120
    )
    .padding()
}
