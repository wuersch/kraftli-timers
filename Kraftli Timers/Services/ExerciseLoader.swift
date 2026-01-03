//
//  ExerciseLoader.swift
//  Kraftli Timers
//
//  Loads exercise data from bundled JSON (with future support for remote loading).
//

import Foundation
import os

/// Data transfer object for JSON decoding
struct ExerciseData: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let formTips: [String]
    let muscleGroup: MuscleGroup
    let difficulty: Difficulty?
}

/// Loads exercises from bundled JSON file.
/// Designed for future extension to support remote loading with bundled fallback.
enum ExerciseLoader {

    /// Load exercises asynchronously.
    /// Currently loads from bundle; will support remote loading with bundled fallback.
    static func load() async -> [ExerciseData] {
        // Future: try remote first, fall back to bundled
        // if let remote = try? await fetchRemote() { return remote }
        loadBundled()
    }

    /// Load exercises from bundled Exercises.json (synchronous).
    /// Used for initial seeding during app launch.
    static func loadBundled() -> [ExerciseData] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            Logger.data.warning("Exercises.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ExerciseData].self, from: data)
        } catch {
            Logger.data.error("Failed to load exercises: \(error.localizedDescription)")
            return []
        }
    }
}
