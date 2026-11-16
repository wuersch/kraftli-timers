//
//  ExerciseLoader.swift
//  Kraftli Timers
//
//  Loads exercise data from bundled JSON (with future support for remote loading).
//

import Foundation
import os

/// Loads exercises from bundled JSON file.
enum ExerciseLoader {

    /// Load exercises from bundled Exercises.json (synchronous).
    /// Used for initial seeding during app launch.
    static func loadBundled() -> [ExerciseInfo] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            Logger.data.warning("Exercises.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ExerciseInfo].self, from: data)
        } catch {
            Logger.data.error("Failed to load exercises: \(error.localizedDescription)")
            return []
        }
    }
}
