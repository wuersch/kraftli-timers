//
//  WorkoutSummaryView.swift
//  Kraftli Timers
//
//  Post-workout summary screen showing health metrics from Apple Watch.
//  Based on design option E4: three cards with colored captions.
//

import SwiftUI

/// Displays a summary of the completed workout with health metrics.
///
/// Shows duration, calories, and heart rate data collected from Apple Watch.
/// Includes confetti celebration and a link to open the Health app.
///
/// ## Usage
/// Present as a full-screen cover after workout completion when
/// `WorkoutSummaryData.hasHealthData` is true and the setting is enabled.
struct WorkoutSummaryView: View {
    let data: WorkoutSummaryData
    let confettiEnabled: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                content
                dragIndicator
                dismissHint
                if confettiEnabled {
                    ConfettiView()
                }
            }
            .navigationTitle("\(data.exerciseName)\(UISeparator.dot)\(data.timerKind.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .gesture(dismissGesture)
    }

    // MARK: - Content

    private var content: some View {
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

    // MARK: - Overlays

    private var dragIndicator: some View {
        VStack {
            Capsule()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 32, height: 4)
                .padding(.top, 12)
            Spacer()
        }
    }

    private var dismissHint: some View {
        VStack {
            Spacer()
            Text("Swipe down to close")
                .font(.system(size: 15))
                .foregroundStyle(.gray.opacity(0.6))
                .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                // Dismiss on downward swipe
                if value.translation.height > 100 {
                    dismiss()
                }
            }
    }

    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Previews

#Preview("Full Data") {
    WorkoutSummaryView(
        data: WorkoutSummaryData(
            exerciseName: "6-Count Burpees",
            timerKind: .emom,
            duration: 20 * 60,
            reps: 100,
            rounds: nil,
            averageHeartRate: 152,
            maxHeartRate: 174,
            activeCalories: 156
        ),
        confettiEnabled: true
    )
    .preferredColorScheme(.dark)
}

#Preview("AMRAP") {
    WorkoutSummaryView(
        data: WorkoutSummaryData(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            duration: 15 * 60,
            reps: nil,
            rounds: 8,
            averageHeartRate: 145,
            maxHeartRate: 168,
            activeCalories: 120
        ),
        confettiEnabled: false
    )
    .preferredColorScheme(.dark)
}

#Preview("HR Only") {
    WorkoutSummaryView(
        data: WorkoutSummaryData(
            exerciseName: "Kettlebell Swings",
            timerKind: .emom,
            duration: 10 * 60,
            reps: 50,
            rounds: nil,
            averageHeartRate: 140,
            maxHeartRate: 165,
            activeCalories: nil
        ),
        confettiEnabled: false
    )
    .preferredColorScheme(.dark)
}

#Preview("Calories Only") {
    WorkoutSummaryView(
        data: WorkoutSummaryData(
            exerciseName: "Squats",
            timerKind: .emom,
            duration: 5 * 60,
            reps: 25,
            rounds: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            activeCalories: 45
        ),
        confettiEnabled: false
    )
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    WorkoutSummaryView(
        data: WorkoutSummaryData(
            exerciseName: "6-Count Burpees",
            timerKind: .emom,
            duration: 20 * 60,
            reps: 100,
            rounds: nil,
            averageHeartRate: 152,
            maxHeartRate: 174,
            activeCalories: 156
        ),
        confettiEnabled: true
    )
    .preferredColorScheme(.light)
}
