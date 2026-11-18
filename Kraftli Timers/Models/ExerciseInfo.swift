//
//  ExerciseInfo.swift
//  Kraftli Timers
//
//  Lightweight exercise data for in-memory use.
//  Loaded from bundled JSON, not persisted to SwiftData.
//

import Foundation

/// Lightweight exercise data for in-memory use.
///
/// Exercises are static reference data, decoded straight from the bundled JSON at app
/// startup (ADR-0009).
/// Only the exercise ID is persisted in TimerPreset; exercise details are
/// looked up from ExerciseRepository when needed.
struct ExerciseInfo: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let name: String
    let description: String
    let formTips: [String]
    let muscleGroup: MuscleGroup
    let difficulty: Difficulty?
    /// A hold is held for time (a plank), not counted in reps. Holds can't be used
    /// for a For Time timer (UC-0006).
    let isHold: Bool
    /// The typical time one rep takes at a steady pace, before fatigue. Used to
    /// estimate how long a For Time timer takes (UC-0013); `nil` for holds.
    let secondsPerRep: Double?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        formTips: [String],
        muscleGroup: MuscleGroup,
        difficulty: Difficulty? = nil,
        isHold: Bool = false,
        secondsPerRep: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.formTips = formTips
        self.muscleGroup = muscleGroup
        self.difficulty = difficulty
        self.isHold = isHold
        self.secondsPerRep = secondsPerRep
    }
}
