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

            // A step of a session names it (UC-0008).
            if let sessionName = workout.sessionName {
                Label(sessionName, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .cardStyle(padded: false)
        .contentShape(Rectangle())
        .onTapGesture {
            didTapEdit?(workout)
        }
        // A tap gesture is invisible to VoiceOver unless the row says it acts like a button.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(didTapEdit == nil ? [] : .isButton)
        .accessibilityHint(didTapEdit == nil ? "" : "Edits the workout")
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
