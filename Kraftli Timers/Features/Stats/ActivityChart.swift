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
                    y: .value("Minutes", dataPoint.minutes)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                if selectedPeriod == .month {
                    // Use automatic spacing for month (too many days to show all)
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(xAxisLabel(for: date))
                                    .font(.caption2)
                            }
                        }
                    }
                } else {
                    // Show all labels for week (7 days) and year (12 months)
                    AxisMarks(values: chartData.map(\.date)) { value in
                        if let date = value.as(Date.self) {
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
            .frame(height: 200)
            .accessibilityLabel("Activity chart showing \(totalMinutes) total minutes across \(chartData.count) \(selectedPeriod == .year ? "months" : "days")")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    /// Formats date for x-axis labels based on the selected period.
    /// - Week: Mon, Tue, Wed, etc.
    /// - Month: Day numbers (1, 8, 15, 22, 29)
    /// - Year: Single letter month (J, F, M, A, M, J, J, A, S, O, N, D)
    private func xAxisLabel(for date: Date) -> String {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .week:
            // Short weekday: Mon, Tue, Wed, etc.
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)

        case .month:
            // Day of month: 1, 8, 15, etc.
            let day = calendar.component(.day, from: date)
            return "\(day)"

        case .year:
            // Single letter month: J, F, M, etc.
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMMM" // Single letter month
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
