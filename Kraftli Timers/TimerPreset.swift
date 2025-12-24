//
//  TimerPreset.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 24.12.2025.
//

import Foundation

struct TimerPreset: Identifiable, Equatable {
    let id: UUID

    let kind: TimerKind
    let duration: Duration

    let targetReps: Int?

    let exercise: Exercise
}

extension TimerPreset {
    static let defaults: [TimerPreset] = [
        TimerPreset(
            id: UUID(),
            kind: .emom,
            duration: .seconds(20 * 60),
            targetReps: 100,
            exercise: Exercise(name: "6-Count Burpees")
        ),

        TimerPreset(
            id: UUID(),
            kind: .emom,
            duration: .seconds(20 * 60),
            targetReps: 35,
            exercise: Exercise(name: "Navy Seals")
        ),
    ]

    var primaryText: String {
        let minutes = duration.components.seconds / 60
        return "\(kind.rawValue) ⸱ \(minutes) min"
    }

    var secondaryText: String {
        var parts: [String] = [exercise.name]

        if let reps = targetReps {
            parts.append("\(reps) Reps")
        }

        return parts.joined(separator: " · ")
    }

    var intervalDuration: Duration? {
        guard kind == .emom, let reps = targetReps, reps > 0 else {
            return nil
        }

        let totalSeconds = duration.components.seconds
        let intervalSeconds = totalSeconds / Int64(reps)
        
        return .seconds(intervalSeconds)
    }
}

enum TimerKind: String {
    case emom = "EMOM"
    case amrap = "AMRAP"
}

struct Exercise: Equatable {
    let name: String
}
