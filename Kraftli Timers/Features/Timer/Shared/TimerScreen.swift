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

    /// Identifies the workout on both devices; also used as the `WorkoutLog.id`.
    var workoutID = UUID()

    /// When true, the countdown + timer start automatically on first appear
    /// (e.g. launched from the preset play button), mirroring the Watch behavior.
    var autoStart = false

    /// False keeps the workout on the iPhone without asking the Watch (see
    /// `PhoneWorkoutStarter.start`).
    var startsOnWatch = true

    /// Names the run when the workout is a step of a session (ADR-0012).
    var session: SessionContext? = nil

    /// The state the presenting view shares with the screen. nil for a standalone screen
    /// (previews), which then keeps its own.
    var chrome: TimerChrome? = nil

    /// Shown under the total time; a session puts its progress there. `AnyView` erases
    /// the view's type, so this struct needn't be generic over what a parent passes.
    var footer: AnyView? = nil

    /// Called when Watch sends a stop command - parent should dismiss.
    var onDismissRequested: (() -> Void)? = nil
}

// MARK: - What follows from the kind

/// The kind-specific look of the parts the screen draws itself.
struct TimerScreenStyle {
    /// Layout sizes for the available space.
    let sizes: (CGSize) -> TimerSizes
    /// Size of the "Starting on Watch" icon, relative to the primary font.
    let startingIconScale: CGFloat
    /// Size of the 3-2-1 countdown, relative to the primary font.
    let countdownScale: CGFloat
}

extension TimerKind {
    /// EMOM has two rings and needs its own layout; the one-ring kinds share AMRAP's.
    var screenStyle: TimerScreenStyle {
        switch self {
        case .emom:
            TimerScreenStyle(sizes: { TimerSizes.emom(for: $0) }, startingIconScale: 0.6, countdownScale: 1.5)
        case .amrap, .forTime:
            TimerScreenStyle(sizes: { TimerSizes.amrap(for: $0) }, startingIconScale: 0.5, countdownScale: 1.2)
        }
    }
}

/// Where the workout stands, as far as the screen's hint and VoiceOver are concerned.
enum TimerPhase {
    /// Not started yet: waiting for the Watch, counting down, or waiting for a tap.
    case notStarted
    case running
    case paused
    case completed
}

extension TimerRunningTap {
    /// The hint while running. A long press pauses the kinds whose tap means something else.
    var hint: String {
        switch self {
        case .pause: "Tap to pause"
        case .countRound: "Tap to count · Hold to pause"
        case .declareDone: "Tap when done · Hold to pause"
        }
    }

    /// The same for VoiceOver.
    var accessibilityHint: String {
        switch self {
        case .pause: "Tap to pause"
        case .countRound: "Tap to add round, hold to pause"
        case .declareDone: "Tap when done, hold to pause"
        }
    }

    /// Whether a long press pauses and resumes (the kinds whose tap means something else).
    var holdTogglesPause: Bool {
        self != .pause
    }
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
    /// The tap hint for the current phase, even while hidden (it reserves the hint's
    /// space).
    let hint: String
    /// The text for the hint line: a sync notice takes precedence over the tap hint.
    /// nil while the hint is hidden.
    let visibleHint: String?
    /// True while `visibleHint` is a sync notice, which is longer than a tap hint.
    let showsSyncNotice: Bool
}

// MARK: - Shared pieces for the kinds

/// The center of a kind's ring: a label, the big value, and under it the hint line —
/// or, while the hint is hidden, the kind's `footer`.
struct TimerCenterStack<Footer: View>: View {
    let label: String
    let value: String
    var weight: Font.Weight = .bold
    var color: Color = .primary
    let accessibilityLabel: String
    var accessibilityValue: String = ""
    let context: TimerScreenContext
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: context.sizes.labelFont))
                .foregroundStyle(.gray)

            Text(value)
                .font(.system(size: context.sizes.primaryFont, weight: weight, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(accessibilityValue)

            if let visibleHint = context.visibleHint {
                Text(visibleHint)
                    .font(.system(size: context.sizes.labelFont))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    // A sync notice is longer than a tap hint, so it may shrink further.
                    .minimumScaleFactor(context.showsSyncNotice ? 0.6 : 0.8)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .accessibilityHidden(true)
            } else {
                footer()
            }
        }
    }
}

extension TimerCenterStack where Footer == TimerHintPlaceholder {
    /// A center whose hint line stays empty while the hint is hidden, without the layout
    /// shifting.
    init(
        label: String,
        value: String,
        weight: Font.Weight = .bold,
        color: Color = .primary,
        accessibilityLabel: String,
        accessibilityValue: String = "",
        context: TimerScreenContext
    ) {
        self.init(
            label: label, value: value, weight: weight, color: color,
            accessibilityLabel: accessibilityLabel, accessibilityValue: accessibilityValue,
            context: context
        ) {
            TimerHintPlaceholder(context: context)
        }
    }
}

/// Keeps the hint line's space while the hint is hidden, so the center doesn't jump.
struct TimerHintPlaceholder: View {
    let context: TimerScreenContext

    var body: some View {
        Text(context.hint)
            .font(.system(size: context.sizes.labelFont))
            .lineLimit(1)
            .hidden()
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
struct TimerScreen<Model: TimerModel, Ring: View, Center: View>: View {
    // MARK: - Properties
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(PhoneWorkoutStarter.self) private var workoutStarter

    /// The chrome of a standalone screen; see `chrome`.
    @State private var ownChrome = TimerChrome()
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
    /// The workout to start. Its ID comes from `link`.
    let config: TimerConfig
    let link: TimerScreenLink
    let total: TimerScreenTotal
    /// What VoiceOver says about the workout after its phase ("12 rounds completed").
    let accessibilitySummary: String
    @ViewBuilder let ring: (TimerScreenContext) -> Ring
    @ViewBuilder let center: (TimerScreenContext) -> Center

    // MARK: - Computed Properties
    private var isCompleted: Bool { model.isCompleted }
    private var workoutID: UUID { link.workoutID }
    private var chrome: TimerChrome { link.chrome ?? ownChrome }
    private var runningTap: TimerRunningTap { config.kind.runningTap }
    private var style: TimerScreenStyle { config.kind.screenStyle }

    private var phase: TimerPhase {
        if isCompleted { return .completed }
        if model.isRunning { return .running }
        return workoutState?.isPaused == true ? .paused : .notStarted
    }

    /// The tap hint for the current phase.
    private var hintText: String {
        switch phase {
        case .notStarted: "Tap to start"
        case .running: runningTap.hint
        case .paused: "Tap to resume"
        case .completed: ""
        }
    }

    private var accessibilityLabel: String {
        let kind = config.kind.rawValue
        let status = switch phase {
        case .notStarted: "\(kind) timer ready"
        case .running: "\(kind) timer running"
        case .paused: "\(kind) timer paused"
        case .completed: "Timer completed"
        }
        return accessibilitySummary.isEmpty ? status : "\(status), \(accessibilitySummary)"
    }

    private var accessibilityHint: String {
        let action = switch phase {
        case .notStarted: "Tap to start"
        case .running: runningTap.accessibilityHint
        case .paused: runningTap.holdTogglesPause ? "Tap or hold to resume" : "Tap to resume"
        case .completed: ""
        }
        return action.isEmpty ? "Swipe down to close" : "\(action), swipe down to close"
    }

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
        return syncNotice ?? (chrome.showHint ? hintText : nil)
    }

    private func context(sizes: TimerSizes) -> TimerScreenContext {
        TimerScreenContext(
            sizes: sizes,
            isCompleted: isCompleted,
            isWaitingToStart: isWaitingToStart,
            hint: hintText,
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
        workoutStarter.start(
            workoutID: workoutID, config: config, onWatch: link.startsOnWatch, session: link.session
        )
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
              case .record(let result) = EarlyStop(of: state, at: Date())
        else { return }
        link.onWorkoutStopped?(completionData(result, stoppedEarly: true))
    }

    /// The report of this workout with `result`. Whoever owns the timer saves the Health
    /// workout (ADR-006 §1).
    private func completionData(_ result: WorkoutResult, stoppedEarly: Bool = false) -> WorkoutCompletionData {
        WorkoutCompletionData(
            result,
            ownedByWatch: timerSession.renderedState?.owner == .watch,
            correlationID: workoutID,
            stoppedEarly: stoppedEarly
        )
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
        ) { [chrome, model] in
            chrome.onTimerStarted { model.isRunning }
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
        guard let isPaused, chrome.hasEverStarted else { return }
        if isPaused {
            chrome.onTimerPaused()
        } else {
            chrome.onTimerStarted { [model] in model.isRunning }
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

                VStack(spacing: 26) {
                    TimerBottomSection(
                        time: total.time,
                        isWaitingToStart: isWaitingToStart,
                        sizes: sizes,
                        isCompleted: isCompleted,
                        totalDuration: total.totalDuration,
                        countsUp: total.countsUp,
                        showsWatchDisconnected: timerSession.hasUnconfirmedChanges
                    )
                    if let footer = link.footer {
                        footer
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            .modifier(HoldGesture(isEnabled: runningTap.holdTogglesPause, action: handleLongPress))
        }
        .timerLifecycle(
            timer: model,
            chrome: chrome,
            onPause: { timerSession.pause() },
            onDisappear: { cleanupForDismiss() },
            onWorkoutCompleted: {
                link.onWorkoutCompleted?(completionData(model.result))
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
            // Lets the presenting view end the workout (swipe-down).
            chrome.endWorkout = cleanupForDismiss
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
        // No swipe-down during the countdown.
        .onChange(of: countdown.isCountingDown) { _, isCountingDown in
            chrome.isSwipeDisabled = isCountingDown
        }
    }

    // MARK: - Starting On Watch Content
    private func startingOnWatchContent(sizes: TimerSizes) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: sizes.primaryFont * style.startingIconScale))
                .foregroundStyle(config.kind.color)
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
