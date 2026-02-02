//
//  ExerciseRepository.swift
//  Kraftli Timers
//
//  In-memory repository for exercise reference data.
//  Exercises are static data loaded from bundled JSON - no persistence needed.
//

import Foundation

/// In-memory repository for exercise reference data.
///
/// Exercises are static data loaded from bundled JSON at app startup.
/// This replaces SwiftData persistence for exercises, eliminating CloudKit
/// sync issues (duplicates, race conditions) for data that never changes.
///
/// ## Usage
/// Call `load()` once at app startup before accessing exercises:
/// ```swift
/// ExerciseRepository.load()
/// let exercises = ExerciseRepository.all
/// let burpees = ExerciseRepository.exercise(byId: someId)
/// ```
enum ExerciseRepository {
    private static var exercises: [ExerciseInfo] = []
    private static var exercisesById: [UUID: ExerciseInfo] = [:]

    /// Load exercises from bundle. Call once at app startup.
    ///
    /// This populates the in-memory cache with exercises from Exercises.json.
    /// Must be called before accessing `all` or `exercise(byId:)`.
    static func load() {
        let data = ExerciseLoader.loadBundled()
        exercises = data.map { ExerciseInfo(from: $0) }.sorted { $0.name < $1.name }
        exercisesById = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    /// All exercises, sorted alphabetically by name.
    static var all: [ExerciseInfo] { exercises }

    /// Look up an exercise by its ID.
    /// - Parameter id: The exercise's UUID
    /// - Returns: The exercise if found, nil otherwise
    static func exercise(byId id: UUID) -> ExerciseInfo? {
        exercisesById[id]
    }

    /// Look up an exercise by name.
    /// - Parameter name: The exercise name to search for
    /// - Returns: The first exercise matching the name, nil if not found
    static func exercise(byName name: String) -> ExerciseInfo? {
        exercises.first { $0.name == name }
    }
}
