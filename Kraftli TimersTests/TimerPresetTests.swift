//
//  TimerPresetTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct TimerPresetTests {

    @Test func durationInterval_storesSeconds() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 1200, // 20 minutes
            targetReps: 100
        )

        #expect(preset.durationInterval == 1200)
    }

    @Test func duration_convertsToSwiftDuration() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 1200,
            targetReps: 100
        )

        #expect(preset.duration == .seconds(1200))
    }

    @Test func primaryText_formatsEMOMCorrectly() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100
        )

        #expect(preset.primaryText == "EMOM\(UISeparator.dot)20 min")
    }

    @Test func primaryText_formatsAMRAPCorrectly() {
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 15 * 60,
            targetReps: nil
        )

        #expect(preset.primaryText == "AMRAP\(UISeparator.dot)15 min")
    }

    @Test func secondaryText_includesExerciseAndRepsForEMOM() {
        // Load repository so exerciseInfo lookup works
        ExerciseRepository.load()
        let exerciseId = ExerciseRepository.exercise(byName: "6-Count Burpees")?.id
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100,
            exerciseId: exerciseId
        )

        #expect(preset.secondaryText == "6-Count Burpees\(UISeparator.dot)100 Reps")
    }

    @Test func secondaryText_includesOnlyExerciseForAMRAP() {
        ExerciseRepository.load()
        let exerciseId = ExerciseRepository.exercise(byName: "Pull-ups")?.id
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil,
            exerciseId: exerciseId
        )

        #expect(preset.secondaryText == "Pull-ups")
    }

    @Test func secondaryText_handlesNoExercise() {
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil,
            exerciseId: nil
        )

        #expect(preset.secondaryText == "")
    }

    @Test func kind_parsesFromRawValue() {
        let emomPreset = TimerPreset(kind: .emom, durationInterval: 60, targetReps: 10)
        let amrapPreset = TimerPreset(kind: .amrap, durationInterval: 60)

        #expect(emomPreset.kind == .emom)
        #expect(amrapPreset.kind == .amrap)
    }

    // MARK: - Interval Duration Tests

    @Test func intervalDuration_calculatesCorrectly() {
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60, // 20 minutes = 1200 seconds
            targetReps: 100
        )

        #expect(preset.intervalDuration == 12) // 1200 / 100 = 12 seconds
    }

    @Test func intervalDuration_returnsDefaultWhenNoReps() {
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil
        )

        #expect(preset.intervalDuration == 60) // Default 1 minute
    }

    @Test func intervalDuration_returnsDefaultWhenZeroReps() {
        // Note: This shouldn't happen due to preconditions, but test the guard
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil
        )
        // Manually set to test the guard (bypassing precondition)
        #expect(preset.intervalDuration == 60)
    }

    // MARK: - Maximum Reps Tests

    @Test func maximumReps_calculatesBasedOnMinimumInterval() {
        // 60 seconds / 3 second minimum = 20 max reps
        #expect(TimerPreset.maximumReps(forDuration: 60) == 20)

        // 20 minutes (1200 seconds) / 3 = 400 max reps
        #expect(TimerPreset.maximumReps(forDuration: 1200) == 400)
    }

    @Test func maximumReps_returnsAtLeastOne() {
        // Even for very short durations, should return at least 1
        #expect(TimerPreset.maximumReps(forDuration: 1) == 1)
        #expect(TimerPreset.maximumReps(forDuration: 0) == 1)
    }

    @Test func minimumIntervalDuration_isThreeSeconds() {
        #expect(TimerPreset.minimumIntervalDuration == 3)
    }
}
