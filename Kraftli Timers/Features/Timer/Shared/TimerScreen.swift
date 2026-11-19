//
//  TimerScreen.swift
//  Kraftli Timers
//
//  The screen every timer kind runs on: it starts the workout, follows the timer
//  session, shows the countdown and handles gestures. The kinds (EMOM, AMRAP,
//  For Time) plug in their ring and center content.
//
//  ## SwiftUI: a container view with @ViewBuilder slots
//  `TimerScreen` is generic over the views it is given, the same way `Button` is
//  generic over its label. The initializer takes `@ViewBuilder` closures, so a kind
//  writes its ring and center as ordinary SwiftUI code at the call site, and the
//  compiler knows their concrete types (no `AnyView`, no type erasure). Everything
//  the three kinds used to repeat lives here once.
//

import SwiftUI
import UIKit

// MARK: - Link to the presenting view

/// How a timer screen is connected to the view presenting it (`TimerRunnerView`).
/// The defaults describe a standalone screen, as used in previews.
struct TimerScreenLink {
    /// Called when the workout completes (timer reaches zero, or For Time is declared
    /// done). Used for logging.
    var onWorkoutCompleted: ((WorkoutCompletionData) -> Void)? = nil

    /// Called when the workout was ended early, on either device, after enough active
    /// time to be recorded as stopped early (UC-0005 extension 1a). Used for logging.
    var onWorkoutStopped: ((WorkoutCompletionData) -> Void)? = nil

    /// Exercise name, part of the workout's `TimerConfig`.
    var exerciseName = "Workout"

    /// Identifies the workout on both devices; also used as the `WorkoutLog.id`.
    var workoutID = UUID()

    /// When true, the countdown + timer start automatically on first appear
    /// (e.g. launched from the preset play button), mirroring the Watch behavior.
    var autoStart = false

    /// Parent controls whether swipe is disabled (true during countdown).
    var isSwipeDisabled: Binding<Bool> = .constant(false)

    /// Parent observes hint visibility for overlay.
    var showHint: Binding<Bool> = .constant(true)

    /// Parent manages confetti display (persists across summary transition).
    var showConfetti: Binding<Bool> = .constant(false)

    /// Callback to register cleanup action for parent to call on dismiss.
    var onCleanupForDismiss: ((@escaping () -> Void) -> Void)? = nil

    /// Called when Watch sends a stop command - parent should dismiss.
    var onDismissRequested: (() -> Void)? = nil
}

// MARK: - What a kind configures

/// What a tap does while the workout is running. (A tap starts a workout that hasn't
/// started and resumes a paused one, for every kind.)
enum TimerRunningTap {
    /// EMOM: pause.
    case pause
    /// AMRAP: count a round.
    case countRound
    /// For Time: declare the workout done.
    case declareDone
}

/// The kind-specific look of the parts the screen draws itself.
struct TimerScreenStyle {
    /// Layout sizes for the available space.
    let sizes: (CGSize) -> TimerSizes
    /// Color of the "Starting on Watch" icon.
    let color: Color
    /// Size of the "Starting on Watch" icon, relative to the primary font.
    let startingIconScale: CGFloat
    /// Size of the 3-2-1 countdown, relative to the primary font.
    let countdownScale: CGFloat
}

/// What the bottom section shows.
struct TimerScreenTotal {
    /// Time remaining, or the elapsed time when `countsUp`.
    let time: TimeInterval
    var totalDuration: TimeInterval = 0
    var countsUp = false
}

/// The screen's current state, handed to a kind's ring and center content.
struct TimerScreenContext {
    let sizes: TimerSizes
    let isCompleted: Bool
    /// True before the workout clock starts: waiting for the Watch, or counting down.
    let isWaitingToStart: Bool
    /// The text for the hint line: a sync notice takes precedence over the tap hint.
    /// nil while the hint is hidden.
    let visibleHint: String?
    /// True while `visibleHint` is a sync notice, which is longer than a tap hint.
    let showsSyncNotice: Bool
}

// MARK: - Shared pieces for the kinds

/// The line under the center value showing the tap hint or a sync notice.
struct TimerHintLine: View {
    let text: String
    let context: TimerScreenContext
    /// How far a tap hint may shrink to fit. A sync notice may always shrink to 0.6.
    let minimumScaleFactor: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: context.sizes.labelFont))
            .foregroundStyle(.gray)
            .lineLimit(1)
            .minimumScaleFactor(context.showsSyncNotice ? 0.6 : minimumScaleFactor)
            .transition(
                .opacity.combined(with: .scale(scale: 0.98))
            )
            .accessibilityHidden(true)
    }
}

/// The haptics of the timer screens. Not on `TimerScreen` itself: a generic type
/// can't have static stored properties.
enum TimerHaptics {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let medium = UIImpactFeedbackGenerator(style: .medium)
}

// MARK: - TimerScreen

/// Runs a workout through the app's `TimerSessionController` (ADR-006).
///
/// The screen never runs a stopwatch of its own. `PhoneWorkoutStarter` decides who owns
/// the workout (the Watch if it answers, otherwise the iPhone). Every state the
/// controller renders is handed to `model.apply(_:)`, and gestures become controller
/// actions, so the screen looks the same whichever device owns the timer.
struct TimerScreen<Model: TimerStateRendering, Ring: View, Center: View>: View {
    // MARK: - Properties
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(PhoneWorkoutStarter.self) private var workoutStarter

    @State private var session = TimerSessionState()
    /// The 3-2-1-GO countdown. Each count is signalled through the model's feedback.
    @State private var countdown = CountdownCoordinator()

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

    /// The kind's timer model. Owned by the kind's view (`@State` there).
    let model: Model
    /// The workout to start. Its exercise name and ID come from `link`.
    let config: TimerConfig
    let link: TimerScreenLink
    let style: TimerScreenStyle
    let runningTap: TimerRunningTap
    /// Whether a long press pauses and resumes (the kinds whose tap means something else).
    let holdTogglesPause: Bool
    /// The tap hint for the current state ("Tap to start", …).
    let hintText: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let total: TimerScreenTotal
    @ViewBuilder let ring: (TimerScreenContext) -> Ring
    @ViewBuilder let center: (TimerScreenContext) -> Center

    // MARK: - Computed Properties
    private var isCompleted: Bool { model.isCompleted }
    private var workoutID: UUID { link.workoutID }

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

    /// The text for the hint line: a sync notice takes precedence over the tap hint.
    private var visibleHint: String? {
        guard !isCompleted else { return nil }
        return syncNotice ?? (session.showHint ? hintText : nil)
    }

    private func context(sizes: TimerSizes) -> TimerScreenContext {
        TimerScreenContext(
            sizes: sizes,
            isCompleted: isCompleted,
            isWaitingToStart: isWaitingToStart,
            visibleHint: visibleHint,
            showsSyncNotice: syncNotice != nil
        )
    }

    // MARK: - Actions

    /// Tap: the kind's action while running, resume while paused, start if not started.
    private func handleTap() {
        guard !isCompleted, !countdown.isCountingDown else { return }

        guard let state = workoutState else {
            // Not started yet (no auto-start) — unless we're already waiting for the Watch.
            if !isStartingOnWatch {
                startWorkout()
                TimerHaptics.light.impactOccurred()
            }
            return
        }

        if state.isPaused {
            timerSession.resume()
            TimerHaptics.light.impactOccurred()
            return
        }
        switch runningTap {
        case .pause:
            timerSession.pause()
            TimerHaptics.light.impactOccurred()
        case .countRound:
            timerSession.incrementRound()
            TimerHaptics.light.impactOccurred()
        case .declareDone:
            timerSession.done()
            TimerHaptics.medium.impactOccurred()
        }
    }

    /// Long press: pause while running, resume while paused.
    private func handleLongPress() {
        guard !isCompleted, !countdown.isCountingDown, let state = workoutState else { return }

        if state.isPaused {
            timerSession.resume()
            TimerHaptics.light.impactOccurred()
        } else {
            timerSession.pause()
            TimerHaptics.medium.impactOccurred()
        }
    }

    /// Starts the workout: on the Watch if it confirms in time, otherwise on the iPhone.
    /// The countdown begins once the owner's first snapshot is rendered.
    private func startWorkout() {
        timerSession.onRenderedStateChange = { [model] state in
            model.apply(state)
        }
        workoutStarter.start(workoutID: workoutID, config: config)
    }

    /// Cleanup action called by parent before dismissing. Safe to call more than once.
    private func cleanupForDismiss() {
        reportEarlyStop()
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
        model.reset()
    }

    /// Reports a workout that ends here without having completed, if it ran long enough
    /// to be recorded (`EarlyStop`). Runs before the session is torn down, while its
    /// state still tells how far the workout got, and only on the first cleanup.
    private func reportEarlyStop() {
        guard !isEnding, timerSession.workoutID == workoutID,
              let state = timerSession.renderedState,
              case .record(let activeTime, let reps, let rounds) = EarlyStop(of: state, at: Date())
        else { return }
        link.onWorkoutStopped?(WorkoutCompletionData(
            durationSeconds: activeTime,
            repsCompleted: reps,
            roundsCompleted: rounds,
            // Whoever owns the timer saves the Health workout (ADR-006 §1).
            ownedByWatch: state.owner == .watch,
            correlationID: workoutID,
            stoppedEarly: true
        ))
    }

    /// Shows the 3-2-1-GO countdown toward the workout's shared start date. The timer
    /// model already follows the state; the countdown only displays and signals each count
    /// (a beep, unless Sound is off).
    private func beginCountdown(until startDate: Date) {
        guard countdownStartDate == nil else { return }
        countdownStartDate = startDate
        countdown.startCountdown(
            scheduledStartTime: startDate,
            onCount: { [model] in model.countdownDidCount() }
        ) { [session, model] in
            session.onTimerStarted { model.isRunning }
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
            session.onTimerStarted { [model] in model.isRunning }
        }
    }

    /// The Watch stopped the workout: close the timer, like a local swipe-down.
    private func finishChanged(_ finish: TimerState.Finish?) {
        guard case .stopped = finish, !isEnding else { return }
        cleanupForDismiss()
        link.onDismissRequested?()
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let sizes = style.sizes(geometry.size)
            let context = context(sizes: sizes)

            VStack(spacing: sizes.spacing) {
                // Ring and center content
                ZStack {
                    ring(context)
                        .accessibilityHidden(true)

                    // Center content - switches between starting, countdown and normal display
                    if isStartingOnWatch {
                        startingOnWatchContent(sizes: sizes)
                    } else if countdown.isCountingDown {
                        CountdownText(
                            countdownValue: countdown.countdownValue,
                            fontSize: sizes.primaryFont * style.countdownScale
                        )
                    } else {
                        center(context)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(accessibilityHint)
                .accessibilityAddTraits(isCompleted ? [] : .isButton)

                TimerBottomSection(
                    time: total.time,
                    isWaitingToStart: isWaitingToStart,
                    sizes: sizes,
                    isCompleted: isCompleted,
                    totalDuration: total.totalDuration,
                    countsUp: total.countsUp,
                    showsWatchDisconnected: timerSession.hasUnconfirmedChanges
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .modifier(HoldGesture(isEnabled: holdTogglesPause, action: handleLongPress))
        }
        .timerLifecycle(
            timer: model,
            session: session,
            onPause: { timerSession.pause() },
            onDisappear: { cleanupForDismiss() },
            onWorkoutCompleted: { data in
                var augmented = data
                // Whoever owns the timer saves the Health workout (ADR-006 §1).
                augmented.ownedByWatch = timerSession.renderedState?.owner == .watch
                augmented.correlationID = workoutID
                link.onWorkoutCompleted?(augmented)
            },
            // Backgrounding pauses only a workout the iPhone owns. A Watch-owned one keeps
            // running there, and the display catches up from the state on foreground.
            pausesInBackground: { timerSession.role == .owner },
            // Completes an owned workout whose time ran out while the app was suspended.
            // Does nothing for an open-ended workout, which never runs out.
            onForeground: { timerSession.checkCompletion() }
        )
        .onAppear {
            TimerHaptics.light.prepare()
            TimerHaptics.medium.prepare()
            // Register cleanup action with parent
            link.onCleanupForDismiss?(cleanupForDismiss)
            // Auto-start the countdown + timer when launched from the preset play button.
            // Guarded so a repeated onAppear can't cancel/restart an in-progress countdown.
            if link.autoStart && !didAutoStart {
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
            link.isSwipeDisabled.wrappedValue = newValue
        }
        // Sync hint visibility to parent for overlay
        .onChange(of: session.showHint) { _, newValue in
            link.showHint.wrappedValue = newValue
        }
        // Sync confetti trigger to parent (parent handles display and auto-hide)
        .onChange(of: session.showConfetti) { _, newValue in
            if newValue {
                link.showConfetti.wrappedValue = true
            }
        }
    }

    // MARK: - Starting On Watch Content
    private func startingOnWatchContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: sizes.primaryFont * style.startingIconScale))
                .foregroundStyle(style.color)
                .symbolEffect(.pulse)
            Text("Starting on Watch…")
                .font(.system(size: sizes.labelFont))
                .foregroundStyle(.gray)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Starting on Watch")
    }
}

// MARK: - Hold Gesture

/// Adds the long press only for the kinds that use it, so a kind without one keeps
/// its plain tap behavior.
private struct HoldGesture: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.onLongPressGesture(minimumDuration: 0.8, perform: action)
        } else {
            content
        }
    }
}
