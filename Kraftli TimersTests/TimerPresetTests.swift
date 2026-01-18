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
        let exercise = Exercise(name: "6-Count Burpees", exerciseDescription: "", formTips: [], muscleGroup: .fullBody)
        let preset = TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100,
            exercise: exercise
        )

        #expect(preset.secondaryText == "6-Count Burpees · 100 Reps")
    }

    @Test func secondaryText_includesOnlyExerciseForAMRAP() {
        let exercise = Exercise(name: "Pull-ups", exerciseDescription: "", formTips: [], muscleGroup: .upperBody)
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil,
            exercise: exercise
        )

        #expect(preset.secondaryText == "Pull-ups")
    }

    @Test func secondaryText_handlesNoExercise() {
        let preset = TimerPreset(
            kind: .amrap,
            durationInterval: 20 * 60,
            targetReps: nil,
            exercise: nil
        )

        #expect(preset.secondaryText == "")
    }

    @Test func kind_parsesFromRawValue() {
        let emomPreset = TimerPreset(kind: .emom, durationInterval: 60, targetReps: 10)
        let amrapPreset = TimerPreset(kind: .amrap, durationInterval: 60)

        #expect(emomPreset.kind == .emom)
        #expect(amrapPreset.kind == .amrap)
    }
}
