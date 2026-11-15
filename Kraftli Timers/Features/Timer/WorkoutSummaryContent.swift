//
//  WorkoutSummaryContent.swift
//  Kraftli Timers
//
//  Reusable summary content component showing workout metrics cards.
//  Used inline in TimerRunnerView after workout completion.
//

import SwiftUI
import UIKit

/// Displays workout summary cards with health metrics.
///
/// This is the content portion of the summary without navigation chrome,
/// designed to be embedded inline within `TimerRunnerView` after completion.
///
/// ## Usage
/// ```swift
/// WorkoutSummaryContent(data: summaryData)
/// ```
struct WorkoutSummaryContent: View {
    let data: WorkoutSummaryData

    var body: some View {
        VStack(spacing: 16) {
            header
                .padding(.bottom, 8)

            durationCard
            caloriesCard
            heartRateCard

            footer
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .padding(.bottom, 60)
        .animation(.easeInOut(duration: 0.4), value: data.hasHealthData)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Summary")
                .font(.title2.weight(.semibold))

            Text(data.headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Duration Card

    private var durationCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.durationTitle)
                    .font(.subheadline)
                    .foregroundStyle(.green)

                Text(data.formattedDuration)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                if let pace = data.formattedPace {
                    Text(pace)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .cardStyle()
        .padding(.horizontal, 20)
    }

    // MARK: - Calories Card

    /// Shown with a "--" placeholder while a Watch-owned workout's data is still on its way.
    @ViewBuilder
    private var caloriesCard: some View {
        if data.activeCalories != nil || data.ownedByWatch {
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)

                SummaryMetric(title: "Active Calories", value: data.activeCalories, unit: "CAL", color: .orange)
                Spacer()
            }
            .cardStyle()
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Heart Rate Card

    /// Shows whichever of average and maximum arrived; both as "--" placeholders while a
    /// Watch-owned workout's data is still on its way.
    @ViewBuilder
    private var heartRateCard: some View {
        let isWaiting = data.averageHeartRate == nil && data.maxHeartRate == nil
        if !isWaiting || data.ownedByWatch {
            HStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)

                HStack(alignment: .top, spacing: 0) {
                    if data.averageHeartRate != nil || isWaiting {
                        SummaryMetric(title: "Avg Heart Rate", value: data.averageHeartRate, unit: "BPM", color: .red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if data.maxHeartRate != nil || isWaiting {
                        SummaryMetric(title: "Max Heart Rate", value: data.maxHeartRate, unit: "BPM", color: .red)
                            .opacity(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if data.hasHealthData {
            Button {
                openHealthApp()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                    Text("Open Health")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.green)
            }
        } else if !data.ownedByWatch {
            // No Watch was involved — show hint to connect
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.subheadline)
                Text("Connect Apple Watch for heart rate and calories")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Summary Metric

/// A titled whole-number value with its unit, e.g. "Avg Heart Rate / 142 BPM".
/// A nil value shows "--": the data is expected but hasn't arrived yet.
private struct SummaryMetric: View {
    let title: String
    let value: Double?
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value.map { "\(Int($0))" } ?? "--")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Full Data") {
    WorkoutSummaryContent(
        data: WorkoutSummaryData(
            exerciseName: "6-Count Burpees",
            timerKind: .emom,
            duration: 20 * 60,
            reps: 100,
            rounds: nil,
            ownedByWatch: true,
            averageHeartRate: 152,
            maxHeartRate: 174,
            activeCalories: 156
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("AMRAP") {
    WorkoutSummaryContent(
        data: WorkoutSummaryData(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            duration: 15 * 60,
            reps: nil,
            rounds: 8,
            ownedByWatch: true,
            averageHeartRate: 145,
            maxHeartRate: 168,
            activeCalories: 120
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Waiting for Watch") {
    WorkoutSummaryContent(
        data: WorkoutSummaryData(
            exerciseName: "6-Count Burpees",
            timerKind: .emom,
            duration: 20 * 60,
            reps: 100,
            rounds: nil,
            ownedByWatch: true
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("No Watch") {
    WorkoutSummaryContent(
        data: WorkoutSummaryData(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            duration: 15 * 60,
            reps: nil,
            rounds: 8,
            ownedByWatch: false
        )
    )
    .preferredColorScheme(.dark)
}
