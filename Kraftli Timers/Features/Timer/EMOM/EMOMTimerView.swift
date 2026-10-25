//
//  EMOMTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit

// MARK: - EMOMTimerView

/// Runs an EMOM workout through the app's `TimerSessionController` (ADR-006).
///
/// The view never runs a stopwatch of its own. `PhoneWorkoutStarter` decides who owns
/// the workout (the Watch if it answers, otherwise the iPhone). Every state the
/// controller renders is handed to `timerModel.apply(_:)`, and taps become controller
/// actions, so the screen looks the same whichever device owns the timer.
struct EMOMTimerView: View {
    // MARK: - Properties
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(PhoneWorkoutStarter.self) private var workoutStarter

    @State private var timerModel: EMOMTimerModel
    @State private var session = TimerSessionState()
    @State private var countdown = CountdownCoordinator()
    @State private var isPulsing = false

    /// Guards the one-shot auto-start so a repeated `onAppear` can't relaunch the countdown.
    @State private var didAutoStart = false

    /// The start date the countdown was begun for, so each workout counts down once.
    @State private var countdownStartDate: Date?

    /// Set once this view tears its workout down, so its own stop isn't mistaken for a
    /// stop from the Watch.
    @State private var isEnding = false

    /// A short sync message shown in the hint line ("Synced with Watch", …).
    @State private var syncNotice: String?
    @State private var syncNoticeTask: Task<Void, Never>?

    /// Called when the workout completes (timer reaches zero). Used for logging.
    private let onWorkoutCompleted: ((WorkoutCompletionData) -> Void)?

    /// Whether to show reps count in center instead of interval countdown.
    private let showRepsInCenter: Bool

    /// Exercise name, part of the workout's `TimerConfig`.
    private let exerciseName: String

    /// Identifies the workout on both devices; also used as the `WorkoutLog.id`.
    private let workoutID: UUID

    /// When true, the countdown + timer start automatically on first appear
    /// (e.g. launched from the preset play button), mirroring the Watch behavior.
    private let autoStart: Bool

    // MARK: - Bindings for Parent Coordination

    /// Parent controls whether swipe is disabled (true during countdown).
    @Binding var isSwipeDisabled: Bool

    /// Parent observes hint visibility for overlay.
    @Binding var showHint: Bool

    /// Parent manages confetti display (persists across summary transition).
    @Binding var showConfetti: Bool

    /// Callback to register cleanup action for parent to call on dismiss.
    private let onCleanupForDismiss: ((@escaping () -> Void) -> Void)?

    /// Called when Watch sends a stop command - parent should dismiss.
    private let onDismissRequested: (() -> Void)?

    // MARK: - Haptics
    private static let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Computed Properties
    private var isCompleted: Bool { timerModel.isCompleted }

    /// True while the iPhone waits for the Watch to confirm this workout.
    private var isStartingOnWatch: Bool {
        timerSession.isAwaitingOwner && timerSession.workoutID == workoutID
    }

    // MARK: - Initialization
    init(
        timerModel: EMOMTimerModel = EMOMTimerModel(
            totalReps: 5,
            totalMinutes: 1,
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: SystemSoundFeedback()
        ),
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
        showRepsInCenter: Bool = false,
        exerciseName: String = "Workout",
        workoutID: UUID = UUID(),
        autoStart: Bool = false,
        isSwipeDisabled: Binding<Bool> = .constant(false),
        showHint: Binding<Bool> = .constant(true),
        showConfetti: Binding<Bool> = .constant(false),
        onCleanupForDismiss: ((@escaping () -> Void) -> Void)? = nil,
        onDismissRequested: (() -> Void)? = nil
    ) {
        self.timerModel = timerModel
        self.onWorkoutCompleted = onWorkoutCompleted
        self.showRepsInCenter = showRepsInCenter
        self.exerciseName = exerciseName
        self.workoutID = workoutID
        self.autoStart = autoStart
        self._isSwipeDisabled = isSwipeDisabled
        self._showHint = showHint
        self._showConfetti = showConfetti
        self.onCleanupForDismiss = onCleanupForDismiss
        self.onDismissRequested = onDismissRequested
    }

    // MARK: - Styling
    private var accentColor: Color {
        if isCompleted { return .green }
        return timerModel.isIntervalWarning ? .orange : .blue
    }


    // MARK: - Helpers
    private func makeRepsText(accent: Color) -> AttributedString {
        var attr = AttributedString("\(timerModel.currentInterval)/\(timerModel.totalIntervals) REPS")
        attr.foregroundColor = .primary
        if let repsRange = attr.range(of: " REPS") {
            attr[repsRange].foregroundColor = accent
        }
        return attr
    }

    private var hintText: String {
        if !timerModel.isRunning && timerModel.overallProgress >= 1.0 {
            return "Tap to start"
        } else if timerModel.isRunning {
            return "Tap to pause"
        } else {
            return "Tap to resume"
        }
    }

    /// The text for the hint line: a sync notice takes precedence over the tap hint.
    private var visibleHint: String? {
        guard !isCompleted else { return nil }
        return syncNotice ?? (session.showHint ? hintText : nil)
    }

    // MARK: - Actions
    private func handleTap() {
        guard !isCompleted, !countdown.isCountingDown else { return }

        guard let state = timerSession.renderedState, timerSession.workoutID == workoutID else {
            // Not started yet (no auto-start) — unless we're already waiting for the Watch.
            if !isStartingOnWatch {
                startWorkout()
                Self.lightHaptic.impactOccurred()
            }
            return
        }

        if state.isPaused {
            timerSession.resume()
        } else {
            timerSession.pause()
        }
        Self.lightHaptic.impactOccurred()
    }

    /// Starts the workout: on the Watch if it confirms in time, otherwise on the iPhone.
    /// The countdown begins once the owner's first snapshot is rendered.
    private func startWorkout() {
        timerSession.onRenderedStateChange = { [timerModel] state in
            timerModel.apply(state)
        }
        workoutStarter.start(
            workoutID: workoutID,
            config: TimerConfig(
                timerKindRaw: TimerKind.emom.rawValue,
                totalDuration: timerModel.totalDuration,
                intervalCount: timerModel.totalIntervals,
                exerciseName: exerciseName
            )
        )
    }

    /// Cleanup action called by parent before dismissing. Safe to call more than once.
    private func cleanupForDismiss() {
        isEnding = true
        countdown.cancelCountdown()
        syncNoticeTask?.cancel()
        // Only tear down the session if it still belongs to this workout — a newly
        // presented timer may already have started the next one.
        if timerSession.workoutID == workoutID {
            workoutStarter.cancel()
            timerSession.stop()
            timerSession.onRenderedStateChange = nil
            timerSession.end()
        }
        timerModel.reset()
    }

    /// Shows the 3-2-1-GO countdown toward the workout's shared start date. The timer
    /// model already follows the state; the countdown only displays and beeps.
    private func beginCountdown(until startDate: Date) {
        guard countdownStartDate == nil else { return }
        countdownStartDate = startDate
        countdown.startCountdown(scheduledStartTime: startDate) { [session, timerModel] in
            session.onTimerStarted { timerModel.isRunning }
        }
    }

    private func showSyncNotice(_ text: String) {
        syncNoticeTask?.cancel()
        withAnimation(.easeIn(duration: 0.2)) { syncNotice = text }
        syncNoticeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { syncNotice = nil }
        }
    }

    // MARK: - Session Updates

    /// Follows pause/resume from either device for the hint.
    private func pausedStateChanged(_ isPaused: Bool?) {
        guard let isPaused, session.hasEverStarted else { return }
        if isPaused {
            session.onTimerPaused()
        } else {
            session.onTimerStarted { [timerModel] in timerModel.isRunning }
        }
    }

    /// The Watch stopped the workout: close the timer, like a local swipe-down.
    private func finishChanged(_ finish: TimerState.Finish?) {
        guard case .stopped = finish, !isEnding else { return }
        cleanupForDismiss()
        onDismissRequested?()
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = TimerSizes.emom(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    ZStack {
                        // Rings - stay full during countdown, fill on completion
                        ProgressRing(
                            size: sizes.primaryRing,
                            lineWidth: sizes.primaryLineWidth,
                            progress: isCompleted ? 1.0 : (isWaitingToStart ? 1.0 : timerModel.intervalProgress),
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -89.5
                        )
                        .accessibilityHidden(true)

                        ProgressRing(
                            size: sizes.secondaryRing!,
                            lineWidth: sizes.secondaryLineWidth!,
                            progress: isCompleted ? 1.0 : (isWaitingToStart ? 1.0 : timerModel.overallProgress),
                            color: .primary,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90.5
                        )
                        .accessibilityHidden(true)

                        // Center content - switches between starting, countdown and normal display
                        if isStartingOnWatch {
                            startingOnWatchContent(sizes: sizes)
                        } else if countdown.isCountingDown {
                            countdownCenterContent(sizes: sizes)
                        } else {
                            normalCenterContent(sizes: sizes)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(isCompleted ? "Timer completed" : (timerModel.isRunning ? "Timer running" : "Timer paused"))
                    .accessibilityHint(isCompleted ? "Swipe down to close" : "\(hintText), swipe down to close")
                    .accessibilityAddTraits(isCompleted ? [] : .isButton)

                    TimerBottomSection(
                        totalTimeRemaining: timerModel.totalTimeRemaining,
                        isCountingDown: isWaitingToStart,
                        isPulsing: $isPulsing,
                        sizes: sizes,
                        isCompleted: isCompleted,
                        totalDuration: timerModel.totalDuration,
                        showsWatchDisconnected: timerSession.hasUnconfirmedChanges
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
            }
        }
        .timerLifecycle(
            timer: timerModel,
            session: session,
            onPause: { timerSession.pause() },
            onDisappear: { cleanupForDismiss() },
            onWorkoutCompleted: { data in
                var augmented = data
                // Whoever owns the timer saves the Health workout (ADR-006 §1).
                augmented.watchHandledWorkout = timerSession.renderedState?.owner == .watch
                augmented.correlationID = workoutID
                onWorkoutCompleted?(augmented)
            },
            // Backgrounding pauses only a workout the iPhone owns. A Watch-owned one keeps
            // running there, and the display catches up from the state on foreground.
            isMirroredSessionActive: { timerSession.role != .owner },
            onForeground: { timerSession.checkCompletion() }
        )
        .onAppear {
            Self.lightHaptic.prepare()
            // Register cleanup action with parent
            onCleanupForDismiss?(cleanupForDismiss)
            // Auto-start the countdown + timer when launched from the preset play button.
            // Guarded so a repeated onAppear can't cancel/restart an in-progress countdown.
            if autoStart && !didAutoStart {
                didAutoStart = true
                startWorkout()
            }
        }
        // The owner's first snapshot fixes the start date: count down toward it.
        .onChange(of: timerSession.renderedState?.startDate) { _, startDate in
            guard let startDate, timerSession.workoutID == workoutID else { return }
            beginCountdown(until: startDate)
        }
        .onChange(of: timerSession.renderedState?.isPaused) { _, isPaused in
            pausedStateChanged(isPaused)
        }
        .onChange(of: timerSession.renderedState?.finish) { _, finish in
            finishChanged(finish)
        }
        .onChange(of: timerSession.lastRollbackDate) {
            showSyncNotice("Synced with Watch")
        }
        .onChange(of: workoutStarter.lastFallbackDate) {
            showSyncNotice("Watch not available — running on iPhone")
        }
        // Sync countdown state to parent for swipe disable
        .onChange(of: countdown.isCountingDown) { _, newValue in
            isSwipeDisabled = newValue
        }
        // Sync hint visibility to parent for overlay
        .onChange(of: session.showHint) { _, newValue in
            showHint = newValue
        }
        // Sync confetti trigger to parent (parent handles display and auto-hide)
        .onChange(of: session.showConfetti) { _, newValue in
            if newValue {
                showConfetti = true
            }
        }
    }

    /// True before the workout clock starts: waiting for the Watch, or counting down.
    private var isWaitingToStart: Bool {
        isStartingOnWatch || countdown.isCountingDown
    }

    // MARK: - Starting On Watch Content
    @ViewBuilder
    private func startingOnWatchContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: sizes.primaryFont * 0.6))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
            Text("Starting on Watch…")
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Starting on Watch")
    }

    // MARK: - Countdown Center Content
    @ViewBuilder
    private func countdownCenterContent(sizes: TimerSizes) -> some View {
        CountdownText(
            countdownValue: countdown.countdownValue,
            fontSize: sizes.primaryFont * 1.5
        )
    }

    // MARK: - Normal Center Content
    @ViewBuilder
    private func normalCenterContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 8) {
            Text(showRepsInCenter ? "REPS" : (isCompleted ? "INTERVALS" : "INTERVAL"))
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)

            if showRepsInCenter {
                // Reps-focused mode: show reps count prominently
                Text("\(timerModel.currentInterval)/\(timerModel.totalIntervals)")
                    .font(
                        .system(
                            size: sizes.primaryFont,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Reps completed")
                    .accessibilityValue(
                        "\(timerModel.currentInterval) of \(timerModel.totalIntervals)"
                    )

                // Third element for vertical balance
                if let visibleHint {
                    Text(visibleHint)
                        .font(.system(size: sizes.labelFont))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(syncNotice == nil ? 0.9 : 0.6)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.98))
                        )
                        .accessibilityHidden(true)
                } else {
                    // Small interval countdown as secondary info
                    Text(timerModel.intervalTimeRemaining.formatted)
                        .font(.system(size: sizes.labelFont, weight: .medium, design: .rounded))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .accessibilityLabel("Interval time remaining")
                        .accessibilityValue(timerModel.intervalTimeRemaining.formatted)
                }
            } else {
                // Interval-focused mode: show countdown, or completed intervals when done
                if isCompleted {
                    Text("\(timerModel.completedIntervals)/\(timerModel.totalIntervals)")
                        .font(
                            .system(
                                size: sizes.primaryFont,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Intervals completed")
                        .accessibilityValue(
                            "\(timerModel.completedIntervals) of \(timerModel.totalIntervals)"
                        )
                } else {
                    Text(timerModel.intervalTimeRemaining.formatted)
                        .font(
                            .system(
                                size: sizes.primaryFont,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Interval time")
                        .accessibilityValue(
                            timerModel.intervalTimeRemaining.formatted
                        )
                }

                if let visibleHint {
                    Text(visibleHint)
                        .font(.system(size: sizes.labelFont))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(syncNotice == nil ? 0.9 : 0.6)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.98))
                        )
                        .accessibilityHidden(true)
                } else {
                    RepsPill(text: makeRepsText(accent: accentColor), accentColor: accentColor, fontSize: sizes.pillFont)
                        .accessibilityLabel("Round \(timerModel.currentInterval) of \(timerModel.totalIntervals)")
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("EMOM Timer") {
    NavigationStack {
        EMOMTimerView(
            timerModel: EMOMTimerModel(
                totalReps: 100,
                totalMinutes: 20,
                timerProvider: DisplayLinkTimerProvider(),
                feedbackProvider: SystemSoundFeedback()
            )
        )
    }
    .previewTimerSession()
}

