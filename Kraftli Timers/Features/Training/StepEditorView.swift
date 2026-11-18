//
//  StepEditorView.swift
//  Kraftli Timers
//
//  Editor for one timer of a session (UC-0013).
//

import SwiftUI

/// Creates or changes one step of a session, with the same form as a preset.
///
/// It doesn't store anything: Done hands the step back through `onDone`, and the session
/// editor decides where it goes. The session itself is only saved from there.
struct StepEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let stepID: UUID?
    private let onDone: (SessionStep) -> Void

    @State private var draft: PresetDraft

    /// - Parameter step: The step to change, or `nil` for a new one.
    init(step: SessionStep? = nil, onDone: @escaping (SessionStep) -> Void) {
        self.stepID = step?.id
        self.onDone = onDone
        _draft = State(initialValue: step.map(PresetDraft.init(step:)) ?? PresetDraft())
    }

    var body: some View {
        NavigationStack {
            TimerSettingsForm(draft: $draft)
                .navigationTitle(stepID == nil ? "New Timer" : "Edit Timer")
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

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            onDone(draft.step(id: stepID ?? UUID()))
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel("Done")
                    }
                }
        }
    }
}

#Preview {
    StepEditorView { _ in }
        .onAppear { ExerciseRepository.load() }
}
