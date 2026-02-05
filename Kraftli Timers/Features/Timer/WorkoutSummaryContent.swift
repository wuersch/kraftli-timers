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
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 20)

            header
                .padding(.bottom, 8)

            durationCard
            caloriesCard
            heartRateCard

            healthLink
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Workout completed")
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
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.green)

                Text(data.formattedDuration)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .cardStyle()
        .padding(.horizontal, 20)
    }

    // MARK: - Calories Card

    @ViewBuilder
    private var caloriesCard: some View {
        if let calories = data.activeCalories {
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Calories")
                        .font(.subheadline)
                        .foregroundStyle(.orange)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(calories))")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text("CAL")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .cardStyle()
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Heart Rate Card

    @ViewBuilder
    private var heartRateCard: some View {
        if data.averageHeartRate != nil || data.maxHeartRate != nil {
            HStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)

                HStack(alignment: .top, spacing: 0) {
                    // Avg Heart Rate
                    if let avgHR = data.averageHeartRate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Avg Heart Rate")
                                .font(.subheadline)
                                .foregroundStyle(.red)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(avgHR))")
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)

                                Text("BPM")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Max Heart Rate
                    if let maxHR = data.maxHeartRate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max Heart Rate")
                                .font(.subheadline)
                                .foregroundStyle(.red.opacity(0.7))

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(maxHR))")
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary.opacity(0.7))

                                Text("BPM")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Health Link

    private var healthLink: some View {
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
    }

    // MARK: - Actions

    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
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
            averageHeartRate: 145,
            maxHeartRate: 168,
            activeCalories: 120
        )
    )
    .preferredColorScheme(.dark)
}
