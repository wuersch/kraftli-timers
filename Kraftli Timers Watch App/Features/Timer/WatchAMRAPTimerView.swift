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

    private let exerciseName: String
    private let totalDuration: TimeInterval
    private let workoutID: UUID
    private let startedOnPhone: Bool
    private let syncService: WatchTimerSyncService

    private let timerKind: TimerKind = .amrap
    private var isCompleted: Bool { timerModel.isCompleted }

    init(
        totalDuration: TimeInterval = 20 * 60,
        exerciseName: String = "AMRAP Workout",
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.totalDuration = totalDuration
        self.exerciseName = exerciseName
        self.workoutID = workoutID
        self.startedOnPhone = startedOnPhone
        self.syncService = syncService
        self.timerModel = AMRAPTimerModel(
            totalDuration: totalDuration,
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
                intervalCount: nil,
                exerciseName: exerciseName
            ),
            workoutID: workoutID,
            startedOnPhone: startedOnPhone,
            syncService: syncService,
            metricsTap: .countRound,
            makeWorkoutLog: {
                WorkoutLog(
                    exerciseName: exerciseName,
                    timerKind: timerKind,
                    durationSeconds: totalDuration,
                    roundsCompleted: timerModel.roundsCompleted
                )
            }
        ) {
            // Total remaining
            WatchMetricRow(
                value: isCompleted ? totalDuration.formatted : timerModel.totalTimeRemaining.formatted,
                labelTop: "TOTAL",
                valueColor: isCompleted ? .green : timerKind.color
            )
            // Rounds counted so far
            WatchMetricRow(
                value: "\(timerModel.roundsCompleted)",
                labelTop: "ROUNDS",
                valueColor: isCompleted ? .green : timerKind.color
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchAMRAPTimerView(totalDuration: 60)
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
