//
//  AMRAPTimerView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import SwiftUI
import UIKit
import Combine
import HealthKit
import os

// MARK: - AMRAPTimerView
struct AMRAPTimerView: View {
    // MARK: - Properties
    @Environment(MirroredWorkoutObserver.self) private var mirroredWorkout: MirroredWorkoutObserver?

    @State private var timerModel: AMRAPTimerModel
    @State private var session = TimerSessionState()
    @State private var countdown = CountdownCoordinator()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isPulsing = false

    /// Tracks whether Watch is handling the HKWorkoutSession (Scenario C).
    /// When true, iPhone skips its own HealthKit save to avoid duplicates.
    @State private var watchHandledWorkout = false

    /// Called when the workout completes (timer reaches zero). Used for logging.
    private let onWorkoutCompleted: ((WorkoutCompletionData) -> Void)?

    /// Service for syncing timer controls with Apple Watch (nil for standalone timers).
    private let syncService: TimerSyncService?

    /// Service for HealthKit operations (starting Watch workout sessions).
    private let healthKitService: (any HealthKitService)?

    /// Exercise name for Watch sync message.
    private let exerciseName: String

    /// Pre-generated correlation ID for Watch ↔ iPhone UUID matching.
    private let correlationID: UUID?

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

    // MARK: - Initialization
    init(
        timerModel: AMRAPTimerModel = AMRAPTimerModel(
            timerProvider: DisplayLinkTimerProvider(),
            feedbackProvider: SystemSoundFeedback()
        ),
        onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil,
        syncService: TimerSyncService? = nil,
        healthKitService: (any HealthKitService)? = nil,
        exerciseName: String = "Workout",
        correlationID: UUID? = nil,
        isSwipeDisabled: Binding<Bool> = .constant(false),
        showHint: Binding<Bool> = .constant(true),
        showConfetti: Binding<Bool> = .constant(false),
        onCleanupForDismiss: ((@escaping () -> Void) -> Void)? = nil,
        onDismissRequested: (() -> Void)? = nil
    ) {
        self.timerModel = timerModel
        self.onWorkoutCompleted = onWorkoutCompleted
        self.syncService = syncService
        self.healthKitService = healthKitService
        self.exerciseName = exerciseName
        self.correlationID = correlationID
        self._isSwipeDisabled = isSwipeDisabled
        self._showHint = showHint
        self._showConfetti = showConfetti
        self.onCleanupForDismiss = onCleanupForDismiss
        self.onDismissRequested = onDismissRequested
    }

    // MARK: - Styling
    private let accentColor: Color = .indigo


    // MARK: - Actions
    private func handleTap() {
        guard !isCompleted else { return }

        // Ignore taps during countdown
        guard !countdown.isCountingDown else { return }

        guard timerModel.isRunning else {
            startCountdown()
            Self.lightHaptic.impactOccurred()
            return
        }

        timerModel.incrementRoundsCompleted()
        syncService?.sendTimerControl(.incrementRound) { result in
            if case .failure(let error) = result {
                Logger.timerSync.warning("sendTimerControl(.incrementRound) failed: \(error.localizedDescription)")
            }
        }
        Self.lightHaptic.impactOccurred()
    }

    private func handleLongPress() {
        guard !isCompleted else { return }

        // Ignore long press during countdown
        guard !countdown.isCountingDown else { return }

        if timerModel.isRunning {
            timerModel.pause()
            session.onTimerPaused()
            // Prefer mirrored session for pause (reliable HK path).
            // Fall back to WC message only when no active mirrored session exists.
            if mirroredWorkout?.hasActiveSession == true {
                mirroredWorkout?.pause()
            } else {
                syncService?.sendTimerControl(.pause) { result in
                    if case .failure(let error) = result {
                        Logger.timerSync.warning("sendTimerControl(.pause) failed: \(error.localizedDescription)")
                    }
                }
            }
            Self.mediumHaptic.impactOccurred()
        } else {
            startCountdown()
            Self.lightHaptic.impactOccurred()
        }
    }

    /// Cleanup action called by parent before dismissing.
    private func cleanupForDismiss() {
        countdown.cancelCountdown()
        timerModel.reset()
        syncService?.sendTimerControl(.stop) { result in
            if case .failure(let error) = result {
                Logger.timerSync.warning("sendTimerControl(.stop) failed: \(error.localizedDescription)")
            }
        }
    }

    private func startCountdown() {
        // Skip countdown on resume - timer starts immediately
        if session.hasEverStarted {
            startAndScheduleHintHide()
            // Prefer mirrored session for resume (reliable HK path).
            // Fall back to WC message only when no active mirrored session exists.
            if mirroredWorkout?.hasActiveSession == true {
                mirroredWorkout?.resume()
            } else {
                syncService?.sendTimerControl(.play) { result in
                    if case .failure(let error) = result {
                        Logger.timerSync.warning("sendTimerControl(.play) failed: \(error.localizedDescription)")
                    }
                }
            }
            return
        }

        // Calculate absolute start time (3 seconds from now)
        let scheduledStartTime = Date().addingTimeInterval(3.0)

        // Send timer config to Watch with scheduled start time
        syncService?.startTimerOnWatch(
            kind: .amrap,
            totalDuration: timerModel.totalDuration,
            intervalDuration: nil,
            exerciseName: exerciseName,
            scheduledStartTime: scheduledStartTime,
            correlationID: correlationID,
            completion: nil
        )

        // Trigger HKWorkoutSession on Watch via HealthKit (Scenario C).
        // startWatchApp(toHandle:) can launch the Watch app even when it's closed,
        // so we don't gate on reachability — that would prevent the launch.
        if let healthKitService {
            Task {
                do {
                    try await healthKitService.startWorkoutOnWatch(
                        activityType: .highIntensityIntervalTraining
                    )
                    watchHandledWorkout = true
                } catch {
                    Logger.healthKit.error("Failed to start workout on Watch: \(error.localizedDescription)")
                }
            }
        }

        // Start local countdown
        countdown.startCountdown(scheduledStartTime: scheduledStartTime) { [self] in
            startAndScheduleHintHide()
        }
    }

    private func startAndScheduleHintHide() {
        guard !timerModel.isRunning else { return }
        timerModel.start()
        session.onTimerStarted { [timerModel] in timerModel.isRunning }
    }

    // MARK: - Watch Sync

    private func setupControlSubscription() {
        WatchSyncHandler.setupSubscription(
            syncService: syncService,
            callbacks: WatchSyncCallbacks(
                onPlay: { [self] in
                    if !timerModel.isRunning && !isCompleted && !countdown.isCountingDown {
                        startCountdown()
                    }
                },
                onPause: { [self] in
                    if timerModel.isRunning {
                        timerModel.pause()
                        session.onTimerPaused()
                    }
                },
                onStop: { [self] in
                    // Watch requested stop - cleanup and tell parent to dismiss
                    cleanupForDismiss()
                    onDismissRequested?()
                },
                onIncrementRound: { [self] in
                    if timerModel.isRunning && !isCompleted {
                        timerModel.incrementRoundsCompleted()
                    }
                }
            ),
            cancellables: &cancellables
        )
    }

    // MARK: - Mirrored Session Reconciliation

    /// Reconciles local timer state with the mirrored HKWorkoutSession state.
    ///
    /// When Watch pauses/resumes the workout, the mirrored session on iPhone
    /// receives the state change via HealthKit (reliable, unlike sendMessage).
    /// This method adjusts the local timer to match.
    ///
    /// Loop prevention: if the timer is already in the matching state, this is a no-op.
    private func reconcileMirroredState(_ newState: MirroredWorkoutObserver.SessionState?) {
        guard let newState else { return }

        switch newState {
        case .paused:
            if timerModel.isRunning {
                Logger.timerSync.info("Mirrored session paused → pausing local timer")
                timerModel.pause()
                session.onTimerPaused()
                // Don't send control back — the state change came from Watch
            }
        case .running:
            if !timerModel.isRunning && !isCompleted && session.hasEverStarted {
                Logger.timerSync.info("Mirrored session running → resuming local timer")
                startAndScheduleHintHide()
                // Don't send control back — the state change came from Watch
            }
        case .ended:
            Logger.timerSync.info("Mirrored session ended")
        case .idle:
            break
        }
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
                            progress: isCompleted ? 1.0 : (countdown.isCountingDown ? 1.0 : timerModel.progress),
                            color: accentColor,
                            backgroundColor: Color.gray.opacity(0.2),
                            rotationDegrees: -90
                        )
                        .accessibilityHidden(true)

                        // Center content - switches between countdown and normal display
                        if countdown.isCountingDown {
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
                        isCountingDown: countdown.isCountingDown,
                        isPulsing: $isPulsing,
                        sizes: sizes,
                        isCompleted: isCompleted,
                        totalDuration: timerModel.totalDuration
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
            onPause: { timerModel.pause() },
            onDisappear: { timerModel.pause() },
            onWorkoutCompleted: { data in
                var augmented = data
                augmented.watchHandledWorkout = watchHandledWorkout
                augmented.correlationID = correlationID
                onWorkoutCompleted?(augmented)
            }
        )
        .onAppear {
            Self.lightHaptic.prepare()
            Self.mediumHaptic.prepare()
            setupControlSubscription()
            // Register cleanup action with parent
            onCleanupForDismiss?(cleanupForDismiss)
        }
        .onChange(of: mirroredWorkout?.sessionState) { _, newState in
            reconcileMirroredState(newState)
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

            if session.showHint && !isCompleted {
                Text(hintText)
                    .font(.system(size: sizes.labelFont))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
}
