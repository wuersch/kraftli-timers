//
//  PresetDraftTests.swift
//  Kraftli TimersTests
//
//  The editing rules shared by the iPhone and Watch preset editors.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct PresetDraftTests {

    @Test func newDraft_usesTheDefaults() {
        let draft = PresetDraft()

        #expect(draft.kind == .emom)
        #expect(draft.exerciseId == nil)
        #expect(draft.durationMinutes == 20)
        #expect(draft.targetReps == TimerPreset.defaultForTimeReps)
    }

    @Test func draftOfPreset_takesItsValues() {
        let exerciseId = UUID()
        let preset = TimerPreset(kind: .emom, durationInterval: 600, targetReps: 30, exerciseId: exerciseId)

        let draft = PresetDraft(preset: preset)

        #expect(draft == PresetDraft(kind: .emom, exerciseId: exerciseId, durationMinutes: 10, targetReps: 30))
    }

    /// A For Time preset stores no duration; switching its kind then needs one to offer.
    @Test func draftOfForTimePreset_offersTheDefaultDuration() {
        let preset = TimerPreset(kind: .forTime, durationInterval: 0, targetReps: 50)

        #expect(PresetDraft(preset: preset).durationMinutes == 20)
    }

    @Test func draftOfAMRAPPreset_offersTheDefaultReps() {
        let preset = TimerPreset(kind: .amrap, durationInterval: 300, targetReps: nil)

        #expect(PresetDraft(preset: preset).targetReps == TimerPreset.defaultForTimeReps)
    }

    @Test func repsRange_emom_isCappedByTheDuration() {
        let draft = PresetDraft(kind: .emom, durationMinutes: 1)

        #expect(draft.repsRange == 1...TimerPreset.maximumReps(forDuration: 60))
    }

    @Test func repsRange_forTime_isIndependentOfTheDuration() {
        let draft = PresetDraft(kind: .forTime, durationMinutes: 1)

        #expect(draft.repsRange == TimerPreset.forTimeRepsRange)
    }

    @Test func clampTargetReps_afterSwitchingFromForTimeToEMOM() {
        var draft = PresetDraft(kind: .forTime, durationMinutes: 1, targetReps: 999)

        draft.kind = .emom
        draft.clampTargetReps()

        #expect(draft.targetReps == TimerPreset.maximumReps(forDuration: 60))
    }

    @Test func intervalDuration_dividesTheDurationByTheReps() {
        let draft = PresetDraft(kind: .emom, durationMinutes: 10, targetReps: 20)

        #expect(draft.intervalDuration == 30)
    }

    // MARK: - Holds (UC-0006 extensions 3f, 3g)

    private let plank = ExerciseInfo(name: "Plank", description: "", formTips: [], muscleGroup: .core, isHold: true)
    private let squats = ExerciseInfo(
        name: "Squats", description: "", formTips: [], muscleGroup: .lowerBody, secondsPerRep: 2
    )

    @Test func forTime_cannotBeCombinedWithAHold() {
        #expect(!PresetDraft.canCombine(.forTime, with: plank))
        #expect(PresetDraft.canCombine(.forTime, with: squats))
        #expect(PresetDraft.canCombine(.forTime, with: nil))
    }

    @Test func timeBoxedKinds_canBeCombinedWithAHold() {
        #expect(PresetDraft.canCombine(.emom, with: plank))
        #expect(PresetDraft.canCombine(.amrap, with: plank))
    }

    @Test func forTimeDraft_doesNotOfferHolds() {
        let draft = PresetDraft(kind: .forTime, exerciseId: squats.id)

        #expect(!draft.offers(plank))
        #expect(draft.offers(squats))
    }

    /// A preset saved before the rule existed keeps showing what it has.
    @Test func draft_keepsOfferingItsCurrentExerciseAndKind() {
        let draft = PresetDraft(kind: .forTime, exerciseId: plank.id)

        #expect(draft.offers(plank))
        #expect(draft.offers(.forTime))
    }
}
