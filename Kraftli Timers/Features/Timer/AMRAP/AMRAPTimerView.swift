//
//  AMRAPTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit

// MARK: - AMRAPTimerView

/// Runs an AMRAP workout through the app's `TimerSessionController` (ADR-006).
///
/// Same flow as `EMOMTimerView`: `PhoneWorkoutStarter` decides who owns the workout,
/// every rendered state goes to `timerModel.apply(_:)`, and gestures become controller
/// actions. Rounds are part of the state (`roundCount`), so taps on either device add up.
struct AMRAPTimerView: View {
    // MARK: - Properties
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(PhoneWorkoutStarter.self) private var workoutStarter

    @State private var timerModel: AMRAPTimerModel
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
    private static let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Computed Properties
    private var isCompleted: Bool { timerModel.isCompleted }

    /// True while the iPhone waits for the Watch to confirm this workout.
    private var isStartingOnWatch: Bool {
        timerSession.isAwaitingOwner && timerSession.workoutID == workoutID
    }

    /// True before the workout clock starts: waiting for the Watch, or counting down.
    private var isWaitingToStart: Bool {
        isStartingOnWatch || countdown.isCountingDown
    }

    /// The rendered state of this view's workout, if it has started.
    private var workoutState: TimerState? {
        timerSession.workoutID == workoutID ? timerSession.renderedState : nil
    }

    // MARK: - Initialization
    init(
        timerModel: AMRAPTimerModel = AMRAPTimerModel(
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: SystemSoundFeedback()
        ),
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
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
    private let accentColor: Color = .indigo


    // MARK: - Actions

    /// Tap: count a round while running, resume while paused, start if not started.
    private func handleTap() {
        guard !isCompleted, !countdown.isCountingDown else { return }

        guard let state = workoutState else {
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
            timerSession.incrementRound()
        }
        Self.lightHaptic.impactOccurred()
    }

    /// Long press: pause while running, resume while paused.
    private func handleLongPress() {
        guard !isCompleted, !countdown.isCountingDown, let state = workoutState else { return }

        if state.isPaused {
            timerSession.resume()
            Self.lightHaptic.impactOccurred()
        } else {
            timerSession.pause()
            Self.mediumHaptic.impactOccurred()
        }
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
                timerKindRaw: TimerKind.amrap.rawValue,
                totalDuration: timerModel.totalDuration,
                intervalCount: nil,
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
            let sizes = TimerSizes.amrap(for: geometry.size)

            ZStack {
                VStack(spacing: sizes.spacing) {
                    // Ring and center content
                    ZStack {
                        ProgressRing(
                            size: sizes.primaryRing,
                            lineWidth: sizes.primaryLineWidth,
                            progress: isCompleted ? 1.0 : (isWaitingToStart ? 1.0 : timerModel.progress),
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90
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
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint(accessibilityHint)
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
                .onLongPressGesture(minimumDuration: 0.8) {
                    handleLongPress()
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
            Self.mediumHaptic.prepare()
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

    // MARK: - Starting On Watch Content
    @ViewBuilder
    private func startingOnWatchContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: sizes.primaryFont * 0.5))
                .foregroundStyle(accentColor)
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
            fontSize: sizes.primaryFont * 1.2
        )
    }

    // MARK: - Normal Center Content
    @ViewBuilder
    private func normalCenterContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 8) {
            Text("ROUNDS")
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)

            Text("\(timerModel.roundsCompleted)")
                .font(
                    .system(
                        size: sizes.primaryFont,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(timerModel.roundsCompleted) rounds completed")

            if let visibleHint {
                Text(visibleHint)
                    .font(.system(size: sizes.labelFont))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(syncNotice == nil ? 0.8 : 0.6)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.98))
                    )
                    .accessibilityHidden(true)
            } else {
                // Invisible spacer to prevent layout shift
                Text(hintText)
                    .font(.system(size: sizes.labelFont))
                    .lineLimit(1)
                    .hidden()
            }
        }
    }

    // MARK: - Helpers

    /// The text for the hint line: a sync notice takes precedence over the tap hint.
    private var visibleHint: String? {
        guard !isCompleted else { return nil }
        return syncNotice ?? (session.showHint ? hintText : nil)
    }

    private var hintText: String {
        if !timerModel.isRunning && timerModel.elapsedTime <= 0 {
            return "Tap to start"
        } else if timerModel.isRunning {
            return "Tap to count · Hold to pause"
        } else {
            return "Tap to resume"
        }
    }

    private var accessibilityLabel: String {
        if isCompleted {
            return "Timer completed, \(timerModel.roundsCompleted) rounds"
        } else if timerModel.isRunning {
            return "AMRAP Timer running, \(timerModel.roundsCompleted) rounds completed"
        } else {
            return "AMRAP Timer paused, \(timerModel.roundsCompleted) rounds completed"
        }
    }

    private var accessibilityHint: String {
        if isCompleted {
            return "Swipe down to close"
        } else if timerModel.isRunning {
            return "Tap to add round, hold to pause, swipe down to close"
        } else {
            return "Tap to start, hold to pause, swipe down to close"
        }
    }
}

// MARK: - Preview
#Preview("AMRAP Timer") {
    NavigationStack {
        AMRAPTimerView(
            timerModel: AMRAPTimerModel(
                totalDuration: 5 * 60,
                timerProvider: DisplayLinkTimerProvider(),
                feedbackProvider: SystemSoundFeedback()
            )
        )
    }
    .previewTimerSession()
}
