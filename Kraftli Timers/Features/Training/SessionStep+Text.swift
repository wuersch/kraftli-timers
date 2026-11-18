//
//  SessionStep+Text.swift
//  Kraftli Timers
//
//  How a session step is described in the Training tab and the session editor.
//

import Foundation

extension SessionStep {
    /// The exercise's name; "Unknown" if it is no longer in the library, as in the history.
    var exerciseName: String {
        exerciseId.flatMap(ExerciseRepository.exercise(byId:))?.name ?? "Unknown"
    }

    /// What defines the timer: "5 min" for EMOM and AMRAP, "30 reps" for For Time.
    var primaryQuantity: String {
        switch kind {
        case .emom, .amrap: durationInterval.durationText
        case .forTime: "\(targetReps ?? 0) reps"
        }
    }

    /// What goes with it: the reps of an EMOM, the estimated length of a For Time.
    var secondaryQuantity: String? {
        switch kind {
        case .emom: targetReps.map { "\($0) reps" }
        case .amrap: nil
        case .forTime: SessionEstimate.text(forSeconds: SessionEstimate.seconds(of: self))
        }
    }

    /// "5 min · 50 reps", "4 min", "30 reps · ≈ 4 min"
    var quantityText: String {
        [primaryQuantity, secondaryQuantity].compactMap { $0 }.joined(separator: UISeparator.dot)
    }
}

extension SessionLoop {
    /// "1 min", "30 sec", or "None"
    var restText: String {
        restSeconds > 0 ? TimeInterval(restSeconds).durationText : "None"
    }
}
