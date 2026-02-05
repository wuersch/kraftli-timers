//
//  WorkoutSummaryView.swift
//  Kraftli Timers
//
//  Post-workout summary screen showing health metrics from Apple Watch.
//  This is a standalone presentation wrapper around WorkoutSummaryContent,
//  kept for potential future use as a standalone modal view.
//

import SwiftUI

/// Displays a summary of the completed workout with health metrics.
///
/// Shows duration, calories, and heart rate data collected from Apple Watch.
/// Includes confetti celebration and a link to open the Health app.
///
/// ## Note
/// This view is currently unused as summaries are shown inline in
/// `TimerRunnerView`. Kept for potential future use cases requiring
/// a standalone modal presentation.
struct WorkoutSummaryView: View {
    let data: WorkoutSummaryData
    let confettiEnabled: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WorkoutSummaryContent(data: data)
                dragIndicator
                dismissHint
                if confettiEnabled {
                    ConfettiView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("\(data.exerciseName)\(UISeparator.dot)\(data.timerKind.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .gesture(dismissGesture)
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

    // MARK: - Gesture

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                // Dismiss on downward swipe
                if value.translation.height > 100 {
                    dismiss()
                }
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
