//
//  TimerPresetRow.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 04.01.2026.
//


import SwiftUI
import SwiftData

struct TimerPresetRow: View {
    @Environment(\.editMode) private var editMode
    
    let preset: TimerPreset
    let didTapRun: (TimerPreset) -> Void
    let didTapEdit: (TimerPreset) -> Void

    private var isEditing: Bool {
        editMode?.wrappedValue == .active
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.primaryText).font(.headline).fontWeight(.semibold)
                Text(preset.secondaryText).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if !isEditing {
                Button {
                    didTapRun(preset)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(preset.exercise?.name ?? "timer")")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { didTapEdit(preset) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.primaryText), \(preset.secondaryText)")
    }
}