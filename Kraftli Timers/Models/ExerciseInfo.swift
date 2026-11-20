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

    private enum CodingKeys: String, CodingKey {
        case id, name, description, formTips, muscleGroup, difficulty, isHold, secondsPerRep
    }

    /// `isHold` is optional in the JSON: an exercise without it is counted in reps.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            description: try container.decode(String.self, forKey: .description),
            formTips: try container.decode([String].self, forKey: .formTips),
            muscleGroup: try container.decode(MuscleGroup.self, forKey: .muscleGroup),
            difficulty: try container.decodeIfPresent(Difficulty.self, forKey: .difficulty),
            isHold: try container.decodeIfPresent(Bool.self, forKey: .isHold) ?? false,
            secondsPerRep: try container.decodeIfPresent(Double.self, forKey: .secondsPerRep)
        )
    }
}
