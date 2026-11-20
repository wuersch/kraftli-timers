//
//  WatchKindTimerView.swift
//  Kraftli Timers Watch App
//
//  The Watch timer screen of a kind, built from the workout's TimerConfig.
//

import SwiftUI

/// The Watch timer for a workout's kind, with its model: the Watch's counterpart of
/// the iPhone's `KindTimerView`, and the one place on the Watch that knows which view
/// belongs to a kind.
struct WatchKindTimerView: View {
    let timer: TimerPresentation

    var body: some View {
        switch timer.config.kind {
        case .emom: WatchEMOMTimerView(timer)
        case .amrap: WatchAMRAPTimerView(timer)
        case .forTime: WatchForTimeTimerView(timer)
        }
    }
}

extension TimerPresentation {
    /// A Watch-started workout of `kind`, for previews.
    static func preview(_ kind: TimerKind, duration: TimeInterval = 60, targetReps: Int? = nil) -> Self {
        TimerPresentation(config: TimerConfig(
            kind: kind, duration: duration, targetReps: targetReps, exerciseName: "\(kind.rawValue) Workout"
        ))
    }
}
