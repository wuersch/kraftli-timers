//
//  WeekStripView.swift
//  Kraftli Timers
//
//  The training week as seven day tiles (UC-0014).
//

import SwiftUI

/// Seven day tiles side by side. A training day shows its session's shape; a rest day
/// is an empty outline. Tapping a tile selects the day.
struct WeekStripView: View {
    /// The weekdays in the order to show them (1 = Sunday … 7 = Saturday).
    let weekdays: [Int]
    let today: Int
    @Binding var selectedWeekday: Int
    /// The session planned on a weekday; `nil` for a rest day.
    let session: (Int) -> TrainingSession?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.self) { weekday in
                Button {
                    selectedWeekday = weekday
                } label: {
                    dayTile(weekday)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: weekday))
                .accessibilityAddTraits(weekday == selectedWeekday ? .isSelected : [])
            }
        }
    }

    private func dayTile(_ weekday: Int) -> some View {
        let planned = session(weekday)
        let isToday = weekday == today
        let shape = RoundedRectangle(cornerRadius: 12)

        return VStack(spacing: 8) {
            Text(WeekLayout.shortName(of: weekday))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? Color(UIColor.systemBackground) : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(isToday ? Color.primary : .clear, in: Capsule())

            Group {
                if let planned {
                    SessionShapeColumn(segments: SessionEstimate(of: planned.elements).segments)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Color(UIColor.secondarySystemBackground), in: shape)
                } else {
                    shape.strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .frame(height: 92)
            .overlay {
                if weekday == selectedWeekday {
                    shape.strokeBorder(.primary, lineWidth: 2)
                }
            }
            .contentShape(shape)
        }
        .frame(maxWidth: .infinity)
    }

    private func accessibilityLabel(for weekday: Int) -> String {
        var parts = [WeekLayout.name(of: weekday)]
        if weekday == today { parts.append("today") }
        parts.append(session(weekday)?.name ?? "rest day")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    @Previewable @State var selected = 3
    ExerciseRepository.load()
    let session = TrainingSession(name: "Legs", elements: [
        .step(SessionStep(kind: .emom, exerciseId: nil, durationInterval: 300, targetReps: 50)),
        .step(SessionStep(kind: .amrap, exerciseId: nil, durationInterval: 600, targetReps: nil))
    ])
    return WeekStripView(
        weekdays: WeekLayout.orderedWeekdays(),
        today: 3,
        selectedWeekday: $selected,
        session: { [2, 3, 5].contains($0) ? session : nil }
    )
    .padding()
}
