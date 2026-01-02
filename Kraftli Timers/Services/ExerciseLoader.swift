//
//  ExerciseLoader.swift
//  Kraftli Timers
//
//  Loads exercise data from bundled JSON (with future support for remote loading).
//

import Foundation

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

    /// Load exercises from bundled Exercises.json
    static func loadBundled() -> [ExerciseData] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let exercises = try? JSONDecoder().decode([ExerciseData].self, from: data)
        else {
            return []
        }
        return exercises
    }

    // MARK: - Future: Remote Loading

    /// Load exercises with remote fallback to bundled (for future implementation)
    /// ```
    /// static func load() async -> [ExerciseData] {
    ///     if let remote = try? await fetchRemote() {
    ///         return remote
    ///     }
    ///     return loadBundled()
    /// }
    /// ```
}
