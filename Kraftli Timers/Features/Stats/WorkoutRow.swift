//
//  WorkoutRow.swift
//  Kraftli Timers
//
//  A row displaying a single workout with exercise name, date, and stats.
//

import SwiftUI

/// A card-style row displaying workout information.
struct WorkoutRow: View {
    let workout: WorkoutLog
    var didTapEdit: ((WorkoutLog) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workout.exerciseName)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                Pill(text: workout.timerKind.rawValue, color: workout.timerKind.color, fontSize: 11)
            }

            Text("\(workout.formattedDate)\(UISeparator.dot)\(workout.summaryText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            didTapEdit?(workout)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        WorkoutRow(
            workout: WorkoutLog(
                exerciseName: "6-Count Burpees",
                timerKind: .emom,
                durationSeconds: 1200,
                repsCompleted: 100
            )
        )

        WorkoutRow(
            workout: WorkoutLog(
                exerciseName: "Pull-ups",
                timerKind: .amrap,
                durationSeconds: 900,
                roundsCompleted: 15
            )
        )
    }
    .padding()
}
