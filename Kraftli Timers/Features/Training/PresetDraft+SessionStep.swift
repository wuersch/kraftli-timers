//
//  PresetDraft+SessionStep.swift
//  Kraftli Timers
//
//  A session step is edited with the same draft and rules as a preset (UC-0013 step 3).
//

import Foundation

extension PresetDraft {
    /// A draft for editing `step`.
    init(step: SessionStep) {
        self.init(
            kind: step.kind,
            exerciseId: step.exerciseId,
            durationMinutes: step.durationInterval > 0
                ? Int(step.durationInterval / 60)
                : PresetDraft.defaultDurationMinutes,
            targetReps: step.targetReps ?? TimerPreset.defaultForTimeReps
        )
    }

    /// The draft as a session step. Pass the `id` of the step being edited so it keeps
    /// its identity; a new step gets a new one.
    func step(id: UUID = UUID()) -> SessionStep {
        SessionStep(
            id: id,
            kind: kind,
            exerciseId: exerciseId,
            durationInterval: storedDuration,
            targetReps: storedReps
        )
    }
}
