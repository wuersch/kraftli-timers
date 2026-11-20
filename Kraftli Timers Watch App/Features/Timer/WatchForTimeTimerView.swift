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

    private let exerciseName: String
    private let workoutID: UUID
    private let startedOnPhone: Bool
    private let syncService: WatchTimerSyncService

    private let timerKind: TimerKind = .forTime
    private var isCompleted: Bool { timerModel.isCompleted }

    init(
        targetReps: Int = TimerPreset.defaultForTimeReps,
        exerciseName: String = "For Time Workout",
        workoutID: UUID = UUID(),
        startedOnPhone: Bool = false,
        syncService: WatchTimerSyncService = DefaultWatchTimerSyncService(),
        timerProvider: TimerProvider = FoundationTimerProvider(),
        feedbackProvider: FeedbackProvider = SilentFeedback()
    ) {
        self.exerciseName = exerciseName
        self.workoutID = workoutID
        self.startedOnPhone = startedOnPhone
        self.syncService = syncService
        self.timerModel = ForTimeTimerModel(
            targetReps: targetReps,
            timerProvider: timerProvider,
            feedbackProvider: feedbackProvider
        )
    }

    var body: some View {
        WatchWorkoutScreen(
            model: timerModel,
            config: TimerConfig(
                kind: timerKind,
                totalDuration: nil,
                intervalCount: nil,
                exerciseName: exerciseName,
                targetReps: timerModel.targetReps
            ),
            workoutID: workoutID,
            startedOnPhone: startedOnPhone,
            syncService: syncService
        ) {
            // Elapsed time, counting up; the finish time once done
            WatchMetricRow(
                value: timerModel.elapsedTime.formatted,
                labelTop: isCompleted ? "FINISH" : "ELAPSED",
                valueColor: isCompleted ? .green : timerKind.color
            )
            // Target reps
            WatchMetricRow(
                value: "\(timerModel.targetReps)",
                labelTop: "REPS",
                valueColor: isCompleted ? .green : timerKind.color
            )
        }
    }
}

#Preview {
    NavigationStack {
        WatchForTimeTimerView(targetReps: 50)
    }
    .environment(WatchTimerRuntime.shared.sessionManager)
    .environment(WatchTimerRuntime.shared.timerSession)
    .environment(WatchTimerRuntime.shared.starter)
}
