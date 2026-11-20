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

    private let exerciseName: String
    private let totalDuration: TimeInterval
    private let intervalCount: Int
    private let workoutID: UUID
    private let startedOnPhone: Bool
    private let syncService: WatchTimerSyncService

    private let timerKind: TimerKind = .emom
    private var isCompleted: Bool { timerModel.isCompleted }

    /// Interval row color: orange in the warning window, green when done.
    private var intervalColor: Color {
        if isCompleted { return .green }
        return timerModel.isIntervalWarning ? .orange : timerKind.color
    }

    init(
        totalDuration: TimeInterval = 20 * 60,
        intervalCount: Int = 20,
        exerciseName: String = "EMOM Workout",
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.intervalCount = intervalCount
        self.exerciseName = exerciseName
        self.workoutID = workoutID
        self.startedOnPhone = startedOnPhone
        self.syncService = syncService
        self.timerModel = EMOMTimerModel(
            totalDuration: totalDuration,
            intervalCount: intervalCount,
            timerProvider: timerProvider,
            feedbackProvider: feedbackProvider
        )
    }

    var body: some View {
        WatchWorkoutScreen(
            model: timerModel,
            config: TimerConfig(
                kind: timerKind,
                totalDuration: totalDuration,
                intervalCount: intervalCount,
                exerciseName: exerciseName
            ),
            workoutID: workoutID,
            startedOnPhone: startedOnPhone,
            syncService: syncService
        ) {
            // Total remaining
            WatchMetricRow(
                value: isCompleted ? totalDuration.formatted : timerModel.totalTimeRemaining.formatted,
                labelTop: "TOTAL",
                valueColor: isCompleted ? .green : timerKind.color
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
        WatchEMOMTimerView(
            totalDuration: 60,
            intervalCount: 5
        )
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
