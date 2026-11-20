//
//  WatchEMOMTimerView.swift
//  Kraftli Timers Watch App
//
//  EMOM timer view optimized for watchOS.
//

import SwiftUI

/// The EMOM face of `WatchWorkoutScreen`: total and interval time remaining, and the
/// rep in progress.
struct WatchEMOMTimerView: View {
    @State private var timerModel: EMOMTimerModel
    private let timer: TimerPresentation

    init(_ timer: TimerPresentation) {
        self.timer = timer
        self.timerModel = EMOMTimerModel(
            totalDuration: timer.config.totalDuration ?? 0,
            intervalCount: timer.config.intervalCount ?? 1,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )
    }

    private var isCompleted: Bool { timerModel.isCompleted }
    private var kindColor: Color { TimerKind.emom.color }

    /// Interval row color: orange in the warning window, green when done.
    private var intervalColor: Color {
        if isCompleted { return .green }
        return timerModel.isIntervalWarning ? .orange : kindColor
    }

    var body: some View {
        WatchWorkoutScreen(model: timerModel, timer: timer) {
            // Total remaining
            WatchMetricRow(
                value: isCompleted ? timerModel.totalDuration.formatted : timerModel.totalTimeRemaining.formatted,
                labelTop: "TOTAL",
                valueColor: isCompleted ? .green : kindColor
            )
            // Interval remaining
            WatchMetricRow(
                value: timerModel.intervalTimeRemaining.formatted,
                labelTop: "INTERVAL",
                valueColor: intervalColor
            )
            // Reps: the interval currently in progress / total, matching the
            // iPhone's 1-based `currentInterval` display (starts at 1/N, ends N/N).
            WatchMetricRow(
                value: "\(timerModel.currentInterval)/\(timerModel.totalIntervals)",
                labelTop: "REPS"
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchEMOMTimerView(.preview(.emom, targetReps: 5))
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
