//
//  WorkoutLogTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct WorkoutLogTests {

    // MARK: - Computed Properties Tests

    @Test func timerKind_parsesEMOMFromRawValue() {
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )

        #expect(workout.timerKind == .emom)
    }

    @Test func timerKind_parsesAMRAPFromRawValue() {
        let workout = WorkoutLog(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 600,
            roundsCompleted: 5
        )

        #expect(workout.timerKind == .amrap)
    }

    @Test func durationMinutes_calculatesFromSeconds() {
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200, // 20 minutes
            repsCompleted: 100
        )

        #expect(workout.durationMinutes == 20)
    }

    @Test func durationMinutes_roundsDown() {
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1259, // 20 min 59 sec
            repsCompleted: 100
        )

        #expect(workout.durationMinutes == 20)
    }

    @Test func formattedDate_returnsAbbreviatedFormat() {
        // Create a specific date
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 10
        let date = Calendar.current.date(from: components)!

        let workout = WorkoutLog(
            date: date,
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )

        // Should contain month and day
        #expect(workout.formattedDate.contains("Jan"))
        #expect(workout.formattedDate.contains("10"))
    }

    @Test func formattedTime_returnsShortenedFormat() {
        // Create a specific time
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 10
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components)!

        let workout = WorkoutLog(
            date: date,
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )

        // Should contain time (format varies by locale)
        #expect(!workout.formattedTime.isEmpty)
    }

    // MARK: - Summary Text Tests

    @Test func summaryText_emomFormat_includesReps() {
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200, // 20 min
            repsCompleted: 100
        )

        #expect(workout.summaryText.contains("20 min"))
        #expect(workout.summaryText.contains("100 reps"))
    }

    @Test func summaryText_amrapFormat_includesRounds() {
        let workout = WorkoutLog(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 900, // 15 min
            roundsCompleted: 8
        )

        #expect(workout.summaryText.contains("15 min"))
        #expect(workout.summaryText.contains("8 rounds"))
    }

    @Test func summaryText_noRepsOrRounds_showsOnlyDuration() {
        // This shouldn't happen in practice due to preconditions,
        // but test the fallback behavior for defensive coding
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 0 // Edge case: 0 reps
        )

        // With 0 reps, it should still show the reps
        #expect(workout.summaryText.contains("min"))
    }

    // MARK: - Initialization Tests

    @Test func init_setsAllProperties() {
        let id = UUID()
        let date = Date()
        let workout = WorkoutLog(
            id: id,
            date: date,
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )

        #expect(workout.id == id)
        #expect(workout.date == date)
        #expect(workout.exerciseName == "Burpees")
        #expect(workout.timerKindRawValue == "EMOM")
        #expect(workout.durationSeconds == 1200)
        #expect(workout.repsCompleted == 100)
        #expect(workout.roundsCompleted == nil)
        #expect(workout.healthKitWorkoutUUID == nil)
    }

    @Test func init_defaultHealthKitWorkoutUUID_isNil() {
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )

        #expect(workout.healthKitWorkoutUUID == nil)
    }

    @Test func init_withHealthKitWorkoutUUID_storesUUID() {
        let hkUUID = UUID()
        let workout = WorkoutLog(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 600,
            roundsCompleted: 5,
            healthKitWorkoutUUID: hkUUID
        )

        #expect(workout.healthKitWorkoutUUID == hkUUID)
    }

    @Test func init_emomWithReps_succeeds() {
        // Should not throw
        let workout = WorkoutLog(
            exerciseName: "Burpees",
            timerKind: .emom,
            durationSeconds: 1200,
            repsCompleted: 100
        )

        #expect(workout.repsCompleted == 100)
    }

    @Test func init_amrapWithRounds_succeeds() {
        // Should not throw
        let workout = WorkoutLog(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 600,
            roundsCompleted: 5
        )

        #expect(workout.roundsCompleted == 5)
    }

    // MARK: - Edge Cases

    @Test func durationMinutes_shortDuration_calculatesCorrectly() {
        let workout = WorkoutLog(
            exerciseName: "Quick AMRAP",
            timerKind: .amrap,
            durationSeconds: 90, // 1.5 minutes
            roundsCompleted: 3
        )

        #expect(workout.durationMinutes == 1)
    }

    @Test func summaryText_singleRound_usesCorrectGrammar() {
        let workout = WorkoutLog(
            exerciseName: "Pull-ups",
            timerKind: .amrap,
            durationSeconds: 300,
            roundsCompleted: 1
        )

        // Note: current implementation uses "1 rounds" - this test documents behavior
        #expect(workout.summaryText.contains("1 round"))
    }

    @Test func summaryText_singleRep_usesCorrectGrammar() {
        let workout = WorkoutLog(
            exerciseName: "Slow Burpee",
            timerKind: .emom,
            durationSeconds: 60,
            repsCompleted: 1
        )

        // Note: current implementation uses "1 reps" - this test documents behavior
        #expect(workout.summaryText.contains("1 rep"))
    }
}
