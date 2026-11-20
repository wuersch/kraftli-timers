//
//  TimerRunnerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 04.01.2026.
//

import SwiftUI
import SwiftData

struct TimerRunnerView: View {
    let preset: TimerPreset

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(PhoneMessageCoordinator.self) private var messageCoordinator

    /// Writes the workout log and, for an iPhone-owned workout, the Health workout.
    @Environment(\.workoutRecorder) private var workoutRecorder

    /// The workout summary, built when the workout completes; the Watch's health figures
    /// are merged in whenever they arrive.
    @State private var summaryData: WorkoutSummaryData?

    /// Whether the summary has replaced the timer (shortly after completion).
    @State private var showsSummary = false

    // MARK: - Swipe Gesture State

    /// Current vertical drag offset.
    @State private var dragOffset: CGFloat = 0

    /// Whether the drag handle is currently active (being dragged).
    @State private var isHandleActive = false

    /// Whether swipe is disabled (true during countdown).
    @State private var isSwipeDisabled = false

    /// Whether to show the swipe hint.
    @State private var showHint = true

    /// Whether to show confetti (triggered by timer completion, persists across summary transition).
    @State private var showConfetti = false

    /// Task to auto-hide confetti after 3 seconds.
    @State private var confettiHideTask: Task<Void, Never>?

    /// Cleanup action registered by timer view, called before dismissing.
    @State private var timerCleanup: (() -> Void)?

    /// Task that auto-transitions to the summary screen after a delay.
    @State private var summaryTransitionTask: Task<Void, Never>?

    /// Plays this workout's sounds. Created once in `onAppear` (it needs the settings from the
    /// environment), not in `body`: SwiftUI re-evaluates `body` on every state change here, and
    /// each new provider would set up the audio session and load its sounds again.
    @State private var feedbackProvider: (any FeedbackProvider)?

    var body: some View {
        NavigationStack {
            ZStack {
                if showsSummary, let data = summaryData {
                    // Show summary inline (replaces timer content)
                    WorkoutSummaryContent(data: data)
                        .transition(.opacity)
                } else if let feedbackProvider {
                    timerContent(feedbackProvider: feedbackProvider)
                        .transition(.opacity)
                }
            }
            .swipeToDismiss(
                dragOffset: $dragOffset,
                isHandleActive: $isHandleActive,
                onDismiss: handleDismiss,
                isDisabled: isSwipeDisabled
            )
            .overlay {
                // Hide handle during countdown
                if !isSwipeDisabled {
                    DragHandleView(isActive: isHandleActive, dragOffset: dragOffset)
                }
            }
            .overlay {
                // Show hint: always for summary, use timer's showHint otherwise
                SwipeHintOverlay(isVisible: shouldShowHint, fontSize: 15)
            }
            .overlay {
                // Confetti persists across timer→summary transition
                if showConfetti && settings.confettiEnabled {
                    ConfettiView()
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: showConfetti) { _, newValue in
                if newValue {
                    confettiHideTask?.cancel()
                    confettiHideTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        showConfetti = false
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard feedbackProvider == nil else { return }
                feedbackProvider = settings.audioEnabled
                    ? settings.completionSoundStyle.makeFeedbackProvider()
                    : SilentFeedback()
            }
            // The Watch's HealthKit summary (heart rate, calories) for this workout.
            .onChange(of: messageCoordinator.lastWorkoutSessionEnded) { _, endedMessage in
                guard let endedMessage, endedMessage.correlationID == correlationID else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    summaryData?.merge(endedMessage)
                }
            }
        }
    }

    /// Whether to show the swipe hint: always on the summary, as the timer says otherwise.
    private var shouldShowHint: Bool {
        showsSummary || showHint
    }

    /// Handles dismiss gesture - cleans up timer if running, then dismisses.
    private func handleDismiss() {
        summaryTransitionTask?.cancel()
        summaryTransitionTask = nil
        if !showsSummary {
            // Timer is showing - call cleanup first. (Once the summary shows, the timer
            // session already ended with the timer view; ADR-006.)
            timerCleanup?()
        }
        dismiss()
    }

    /// The exercise's name as shown on both devices. The workout log falls back to
    /// "Unknown" instead (see `workoutCompleted`).
    private var exerciseName: String {
        preset.exerciseInfo?.name ?? "Workout"
    }

    private var navigationTitle: String {
        "\(preset.exerciseInfo?.name ?? "Timer")\(UISeparator.dot)\(preset.kind.rawValue)"
    }

    /// Pre-generated ID for correlating iPhone's WorkoutLog with Watch's HealthKit UUID.
    /// Sent to Watch via StartTimerMessage, echoed back in WorkoutSessionEndedMessage,
    /// and used as the WorkoutLog.id. @State so SwiftUI re-creating this struct keeps
    /// the ID stable — the Watch echoes the value from start time, and a regenerated
    /// ID would break the match.
    @State private var correlationID = UUID()

    /// The timer for the preset's kind.
    private func timerContent(feedbackProvider: any FeedbackProvider) -> some View {
        KindTimerView(
            config: TimerConfig(
                kind: preset.kind,
                duration: preset.durationInterval,
                targetReps: preset.targetReps,
                exerciseName: exerciseName
            ),
            feedbackProvider: feedbackProvider,
            link: timerScreenLink
        )
    }

    /// Connects the timer screen to this view: logging, the swipe/hint/confetti state it
    /// reports, and the two ways the screen is closed.
    private var timerScreenLink: TimerScreenLink {
        TimerScreenLink(
            onWorkoutCompleted: workoutCompleted,
            onWorkoutStopped: record,
            workoutID: correlationID,
            autoStart: true,
            isSwipeDisabled: $isSwipeDisabled,
            showHint: $showHint,
            showConfetti: $showConfetti,
            onCleanupForDismiss: { cleanup in timerCleanup = cleanup },
            onDismissRequested: { dismiss() }
        )
    }

    /// The timer completed: record the workout and move on to the summary.
    ///
    /// The Watch's health figures may already be here (`PhoneMessageCoordinator` keeps
    /// the last ones) or arrive later (`onChange` above). The WorkoutLog's HealthKit-UUID
    /// update happens in `PhoneMessageCoordinator`, which outlives this view.
    private func workoutCompleted(_ completionData: WorkoutCompletionData) {
        var data = WorkoutSummaryData(
            exerciseName: exerciseName,
            timerKind: preset.kind,
            duration: completionData.durationSeconds,
            reps: completionData.repsCompleted,
            rounds: completionData.roundsCompleted,
            ownedByWatch: completionData.ownedByWatch
        )
        if let endedMessage = messageCoordinator.lastWorkoutSessionEnded,
           endedMessage.correlationID == correlationID {
            data.merge(endedMessage)
        }
        summaryData = data

        // Show the summary after a short delay: confetti plays meanwhile, and the timer
        // stays frozen at 0:00.
        summaryTransitionTask?.cancel()
        summaryTransitionTask = Task {
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                showsSummary = true
            }
        }

        record(completionData)
    }

    /// Writes the workout to the history, and to Apple Health if the iPhone ran it.
    /// Also called for a workout stopped early, which has no summary: the screen closes.
    private func record(_ completionData: WorkoutCompletionData) {
        workoutRecorder.record(
            completionData,
            // A preset whose exercise left the library is recorded as "Unknown" (UC-0005 2a1),
            // even though the screen shows the generic "Workout".
            exerciseName: preset.exerciseInfo?.name ?? "Unknown",
            timerKind: preset.kind
        )
    }
}

#Preview("EMOM") {
    ExerciseRepository.load()
    let exerciseId = ExerciseRepository.exercise(byName: "6-Count Burpees")?.id
    return TimerRunnerView(
        preset: TimerPreset(
            kind: .emom,
            durationInterval: 20 * 60,
            targetReps: 100,
            exerciseId: exerciseId
        )
    )
    .environment(AppSettings())
    .environment(PhoneMessageCoordinator())
    .previewTimerSession()
}

#Preview("AMRAP") {
    ExerciseRepository.load()
    let exerciseId = ExerciseRepository.exercise(byName: "Pull-ups")?.id
    return TimerRunnerView(
        preset: TimerPreset(
            kind: .amrap,
            durationInterval: 15 * 60,
            exerciseId: exerciseId
        )
    )
    .environment(AppSettings())
    .environment(PhoneMessageCoordinator())
    .previewTimerSession()
}
