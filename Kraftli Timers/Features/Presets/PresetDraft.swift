//
//  PresetDraft.swift
//  Kraftli Timers
//
//  The values a preset editor works on, with the rules for editing and saving them.
//  Shared by the iPhone and Watch editors.
//

import Foundation
import SwiftData

/// A timer preset while it is being edited.
///
/// A value type: the editor keeps one in `@State`, binds its controls to the fields and
/// nothing reaches the stored `TimerPreset` until `save` is called. Cancelling simply
/// drops the draft.
struct PresetDraft: Equatable {
    /// The duration offered for a new preset, and for a For Time preset (which stores
    /// none) when its kind is switched to a time-boxed one.
    static let defaultDurationMinutes = 20

    var kind: TimerKind
    var exerciseId: UUID?
    var durationMinutes: Int
    /// EMOM: one rep per interval. For Time: the target. Unused for AMRAP.
    var targetReps: Int

    /// A draft for a new preset.
    init(
        kind: TimerKind = .emom,
        exerciseId: UUID? = nil,
        durationMinutes: Int = PresetDraft.defaultDurationMinutes,
        targetReps: Int = TimerPreset.defaultForTimeReps
    ) {
        self.kind = kind
        self.exerciseId = exerciseId
        self.durationMinutes = durationMinutes
        self.targetReps = targetReps
    }

    /// A draft for editing `preset`.
    init(preset: TimerPreset) {
        self.init(
            kind: preset.kind,
            exerciseId: preset.exerciseId,
            durationMinutes: preset.durationInterval > 0
                ? Int(preset.durationInterval / 60)
                : PresetDraft.defaultDurationMinutes,
            targetReps: preset.targetReps ?? TimerPreset.defaultForTimeReps
        )
    }

    // MARK: - Derived values

    /// The chosen exercise; the library's first one while none is chosen.
    var selectedExercise: ExerciseInfo? {
        guard let exerciseId else {
            return ExerciseRepository.all.first
        }
        return ExerciseRepository.exercise(byId: exerciseId)
    }

    var duration: TimeInterval {
        TimeInterval(durationMinutes * 60)
    }

    /// EMOM caps the reps by the duration; For Time allows 1–999.
    var repsRange: ClosedRange<Int> {
        kind == .forTime
            ? TimerPreset.forTimeRepsRange
            : 1...TimerPreset.maximumReps(forDuration: duration)
    }

    /// The length of one EMOM interval, for display.
    var intervalDuration: TimeInterval {
        guard targetReps > 0 else { return 0 }
        return duration / Double(targetReps)
    }

    // MARK: - Holds

    /// For Time counts reps, so it can't be combined with a hold such as a plank (UC-0006).
    static func canCombine(_ kind: TimerKind, with exercise: ExerciseInfo?) -> Bool {
        !(kind == .forTime && exercise?.isHold == true)
    }

    /// Whether the editor offers `kind` for the chosen exercise. The current kind always
    /// stays offered, so a preset saved before the rule existed can still be shown.
    func offers(_ kind: TimerKind) -> Bool {
        kind == self.kind || Self.canCombine(kind, with: selectedExercise)
    }

    /// Whether the editor offers `exercise` for the chosen kind. The current exercise
    /// always stays offered.
    func offers(_ exercise: ExerciseInfo) -> Bool {
        exercise.id == exerciseId || Self.canCombine(kind, with: exercise)
    }

    /// Why For Time isn't offered, for the editors to show; `nil` while it is.
    var forTimeUnavailableReason: String? {
        offers(.forTime) ? nil : "Exercise is a hold. For Time needs an exercise counted in reps."
    }

    // MARK: - Editing

    /// Keeps the reps within the current kind's range. Call after the duration or the
    /// kind changed: switching from For Time (up to 999) to EMOM may exceed the cap.
    mutating func clampTargetReps() {
        targetReps = min(max(targetReps, repsRange.lowerBound), repsRange.upperBound)
    }

    /// Chooses the library's first exercise if none is chosen yet.
    mutating func selectDefaultExerciseIfNeeded() {
        if exerciseId == nil, let first = ExerciseRepository.all.first {
            exerciseId = first.id
        }
    }

    // MARK: - Saving

    /// The duration as it is stored: For Time has none.
    var storedDuration: TimeInterval {
        kind.hasFixedDuration ? duration : 0
    }

    /// The reps as they are stored: AMRAP has none.
    var storedReps: Int? {
        kind == .amrap ? nil : targetReps
    }

    /// Writes the draft to `existingPreset`, or inserts a new preset at the end of
    /// `presets` when there is none.
    func save(editing existingPreset: TimerPreset?, in modelContext: ModelContext, after presets: [TimerPreset]) {
        if let existingPreset {
            existingPreset.kindRawValue = kind.rawValue
            existingPreset.durationInterval = storedDuration
            existingPreset.targetReps = storedReps
            existingPreset.exerciseId = exerciseId
        } else {
            modelContext.insert(TimerPreset(
                kind: kind,
                durationInterval: storedDuration,
                targetReps: storedReps,
                sortOrder: PresetMaintenance.nextSortOrder(after: presets),
                exerciseId: exerciseId
            ))
        }
    }
}
