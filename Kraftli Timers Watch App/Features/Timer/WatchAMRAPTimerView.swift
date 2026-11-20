//
//  WatchAMRAPTimerView.swift
//  Kraftli Timers Watch App
//
//  AMRAP timer view optimized for watchOS.
//

import SwiftUI

/// The AMRAP face of `WatchWorkoutScreen`: the time remaining and the round count.
///
/// Rounds are part of the timer state: a tap on the metrics counts one, so taps on
/// either device add up, even offline.
struct WatchAMRAPTimerView: View {
    @State private var timerModel: AMRAPTimerModel
    private let timer: TimerPresentation

    init(_ timer: TimerPresentation) {
        self.timer = timer
        self.timerModel = AMRAPTimerModel(
            totalDuration: timer.config.totalDuration ?? 0,
            timerProvider: FoundationTimerProvider(),
            feedbackProvider: SilentFeedback()
        )
    }

    private var isCompleted: Bool { timerModel.isCompleted }
    private var valueColor: Color { isCompleted ? .green : TimerKind.amrap.color }

    var body: some View {
        WatchWorkoutScreen(model: timerModel, timer: timer) {
            // Total remaining
            WatchMetricRow(
                value: isCompleted ? timerModel.totalDuration.formatted : timerModel.totalTimeRemaining.formatted,
                labelTop: "TOTAL",
                valueColor: valueColor
            )
            // Rounds counted so far
            WatchMetricRow(
                value: "\(timerModel.roundsCompleted)",
                labelTop: "ROUNDS",
                valueColor: valueColor
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchAMRAPTimerView(.preview(.amrap))
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
