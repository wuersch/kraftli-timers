//
//  DayPlanSheet.swift
//  Kraftli Timers
//
//  Changes what is planned on one weekday (UC-0014 extensions 3a, 3b).
//

import SwiftUI

/// Offers every session and "Rest day" for one weekday; the current choice is checked.
struct DayPlanSheet: View {
    @Environment(\.dismiss) private var dismiss

    let weekday: Int
    let sessions: [TrainingSession]
    let plannedSessionID: UUID?
    /// Called with the chosen session, or `nil` for a rest day.
    let onPick: (TrainingSession?) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    row(isChosen: session.id == plannedSessionID) {
                        onPick(session)
                    } content: {
                        SessionCardContent(session: session)
                    }
                }

                row(isChosen: plannedSessionID == nil) {
                    onPick(nil)
                } content: {
                    Text("Rest day")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(WeekLayout.name(of: weekday))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(
        isChosen: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> some View
    ) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                content()
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .opacity(isChosen ? 1 : 0)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
