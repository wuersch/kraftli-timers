//
//  PresetMaintenanceTests.swift
//  Kraftli TimersTests
//
//  Verifies semantic-content deduplication: identical-content presets (any UUID)
//  collapse to one, election is deterministic and device-independent, and the
//  primary-device guard prevents cross-device data loss. See issue #43.
//
//  These exercise the *pure decision* functions (`duplicatesToDelete`,
//  `electSurvivor`, `backfillExerciseId`, `contentIdentity`, `nextSortOrder`) on
//  constructed presets. We deliberately avoid a ModelContext/`save()`: saving the
//  TimerPreset↔Exercise graph in a test container crashes under the CloudKit app
//  host (a SwiftData trap unrelated to this logic), and the decisions are exactly
//  what's worth testing — the context delete/save is trivial plumbing.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct PresetMaintenanceTests {

    // MARK: - Helpers

    /// A non-EMOM preset (no targetReps required) with explicit id/sortOrder.
    private func makePreset(
        id: UUID = UUID(),
        durationInterval: TimeInterval = 600,
        targetReps: Int? = nil,
        sortOrder: Int = 0,
        exerciseId: UUID? = nil
    ) -> TimerPreset {
        TimerPreset(
            id: id,
            kind: .amrap,
            durationInterval: durationInterval,
            targetReps: targetReps,
            sortOrder: sortOrder,
            exerciseId: exerciseId
        )
    }

    private func makeExercise() -> Exercise {
        Exercise(name: "Burpees", exerciseDescription: "", formTips: [], muscleGroup: .fullBody)
    }

    // MARK: - Content identity

    @Test func contentIdentity_ignoresIdAndSortOrder() {
        let exercise = UUID()
        let a = makePreset(id: UUID(), sortOrder: 0, exerciseId: exercise)
        let b = makePreset(id: UUID(), sortOrder: 9, exerciseId: exercise)
        // Differ only by id and sortOrder → still semantically identical.
        #expect(a.contentIdentity == b.contentIdentity)
    }

    @Test func contentIdentity_distinguishesDefiningFields() {
        let base = makePreset(durationInterval: 600, targetReps: nil, exerciseId: UUID())
        let differentDuration = makePreset(durationInterval: 900, targetReps: nil, exerciseId: base.exerciseId)
        let differentReps = makePreset(durationInterval: 600, targetReps: 5, exerciseId: base.exerciseId)
        let differentExercise = makePreset(durationInterval: 600, targetReps: nil, exerciseId: UUID())

        #expect(base.contentIdentity != differentDuration.contentIdentity)
        #expect(base.contentIdentity != differentReps.contentIdentity)
        #expect(base.contentIdentity != differentExercise.contentIdentity)
    }

    @Test func contentIdentity_fallsBackToLegacyExerciseRelationship() {
        let exercise = makeExercise()
        // Un-migrated row: exercise relationship set, exerciseId still nil.
        let legacy = makePreset(exerciseId: nil)
        legacy.exercise = exercise
        // Already-migrated row pointing at the same exercise.
        let migrated = makePreset(exerciseId: exercise.id)
        // The fallback makes them identical regardless of migration state.
        #expect(legacy.contentIdentity == migrated.contentIdentity)
    }

    // MARK: - Election

    @Test func electSurvivor_picksLowestIdAndIsPermutationIndependent() {
        let exercise = UUID()
        let candidates = (0..<5).map { _ in makePreset(id: UUID(), exerciseId: exercise) }
        let expected = candidates.min { $0.id.uuidString < $1.id.uuidString }!

        #expect(PresetMaintenance.electSurvivor(among: candidates) === expected)
        #expect(PresetMaintenance.electSurvivor(among: candidates.reversed()) === expected)
        #expect(PresetMaintenance.electSurvivor(among: candidates.shuffled()) === expected)
    }

    // MARK: - Deduplication decision

    @Test func duplicatesToDelete_dropsEveryGroupMemberExceptLowestId() {
        let exercise = UUID()
        let identical = (0..<3).map { _ in makePreset(id: UUID(), exerciseId: exercise) }
        let survivor = identical.min { $0.id.uuidString < $1.id.uuidString }!
        let distinct = makePreset(id: UUID(), durationInterval: 1200, exerciseId: exercise)

        let losers = PresetMaintenance.duplicatesToDelete(
            among: identical + [distinct], deletesDuplicates: true
        )

        #expect(losers.count == 2)
        #expect(!losers.contains { $0 === survivor })   // survivor kept
        #expect(!losers.contains { $0 === distinct })   // distinct preset kept
    }

    @Test func duplicatesToDelete_keepsSemanticallyDistinctPresets() {
        // Same duration/kind but different exercises → nothing is redundant.
        let presets = (0..<3).map { _ in makePreset(id: UUID(), exerciseId: UUID()) }
        let losers = PresetMaintenance.duplicatesToDelete(among: presets, deletesDuplicates: true)
        #expect(losers.isEmpty)
    }

    @Test func duplicatesToDelete_returnsEmptyForNonPrimaryDevice() {
        let exercise = UUID()
        let identical = (0..<3).map { _ in makePreset(id: UUID(), exerciseId: exercise) }
        // Watch defers all deletion — what makes cross-device loss impossible.
        let losers = PresetMaintenance.duplicatesToDelete(among: identical, deletesDuplicates: false)
        #expect(losers.isEmpty)
    }

    // MARK: - Migration rule

    @Test func backfillExerciseId_copiesFromLegacyRelationship() {
        let exercise = makeExercise()
        let preset = makePreset(exerciseId: nil)
        preset.exercise = exercise

        #expect(PresetMaintenance.backfillExerciseId(preset) == true)
        #expect(preset.exerciseId == exercise.id)
    }

    @Test func backfillExerciseId_noOpWhenNothingToMigrate() {
        let exercise = makeExercise()
        // Already has an id → unchanged.
        let migrated = makePreset(exerciseId: exercise.id)
        migrated.exercise = exercise
        #expect(PresetMaintenance.backfillExerciseId(migrated) == false)
        #expect(migrated.exerciseId == exercise.id)

        // No legacy relationship at all → unchanged.
        let bare = makePreset(exerciseId: nil)
        #expect(PresetMaintenance.backfillExerciseId(bare) == false)
        #expect(bare.exerciseId == nil)
    }

    // MARK: - Sort order

    @Test func nextSortOrder_appendsAfterHighest() {
        #expect(PresetMaintenance.nextSortOrder(after: []) == 0)

        let ordered = [0, 1, 2].map { makePreset(sortOrder: $0) }
        #expect(PresetMaintenance.nextSortOrder(after: ordered) == 3)
    }

    @Test func nextSortOrder_avoidsCollisionAfterMiddleDelete() {
        // [0, 2] — index 1 was deleted. `presets.count` would return 2 and
        // collide with the survivor; max+1 returns 3.
        let afterDelete = [0, 2].map { makePreset(sortOrder: $0) }
        #expect(PresetMaintenance.nextSortOrder(after: afterDelete) == 3)
    }
}
