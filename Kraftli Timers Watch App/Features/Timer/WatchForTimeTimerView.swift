//
//  WatchForTimeTimerView.swift
//  Kraftli Timers Watch App
//
//  For Time timer view optimized for watchOS.
//  Counts up; tap to declare done.
//

import SwiftUI

/// The For Time face of `WatchWorkoutScreen` (ADR-0010): the elapsed time and the
/// target reps.
///
/// A tap on the metrics page declares the workout done, which the owner records as a
/// completion at the tap time. Pause and End stay on the controls page.
struct WatchForTimeTimerView: View {
    @State private var timerModel: ForTimeTimerModel
    private let timer: TimerPresentation

    init(_ timer: TimerPresentation) {
        self.timer = timer
        self.timerModel = ForTimeTimerModel(
            targetReps: timer.config.targetReps ?? TimerPreset.defaultForTimeReps,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )
    }

    private var isCompleted: Bool { timerModel.isCompleted }
    private var valueColor: Color { isCompleted ? .green : TimerKind.forTime.color }

    var body: some View {
        WatchWorkoutScreen(model: timerModel, timer: timer) {
            // Elapsed time, counting up; the finish time once done
            WatchMetricRow(
                value: timerModel.elapsedTime.formatted,
                labelTop: isCompleted ? "FINISH" : "ELAPSED",
                valueColor: valueColor
            )
            // Target reps
            WatchMetricRow(
                value: "\(timerModel.targetReps)",
                labelTop: "REPS",
                valueColor: valueColor
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchForTimeTimerView(.preview(.forTime, targetReps: 50))
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
