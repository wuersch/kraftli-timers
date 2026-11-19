//
//  SessionRunnerView.swift
//  Kraftli Timers
//
//  The full-screen runner of a training session (UC-0015).
//

import SwiftUI

/// What a run needs of a session: its name and elements as they were when the athlete
/// pressed Start. Passing this copy instead of the stored session is what keeps a run
/// unaffected by later edits. `Identifiable`, so it can drive `fullScreenCover(item:)`.
struct SessionRunRequest: Identifiable {
    let id = UUID()
    let name: String
    let elements: [SessionElement]

    init(_ session: TrainingSession) {
        name = session.name
        elements = session.elements
    }

    init(name: String, elements: [SessionElement]) {
        self.name = name
        self.elements = elements
    }
}

/// Runs a session: one screen per phase of the run, swapped as the run moves on.
///
/// The view only shows `SessionRunner.run` and forwards the athlete's actions; the
/// rules are in `SessionRun`. A step runs on the same timer screens as a single timer.
struct SessionRunnerView: View {
    let request: SessionRunRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.workoutRecorder) private var workoutRecorder
    @Environment(AppSettings.self) private var settings

    /// Created in `onAppear`, because it needs the recorder from the environment.
    @State private var runner: SessionRunner?
    /// Plays the sounds of every step and, once, the session's completion sound.
    @State private var feedbackProvider: (any FeedbackProvider)?

    @State private var isConfirmingEnd = false
    @State private var showConfetti = false

    // The running step's swipe-down, as in `TimerRunnerView`.
    @State private var dragOffset: CGFloat = 0
    @State private var isHandleActive = false
    @State private var isSwipeDisabled = false
    @State private var showHint = true
    /// Tears down the running step's timer; registered by its screen.
    @State private var timerCleanup: (() -> Void)?

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            if let runner, let feedbackProvider {
                content(runner, feedbackProvider: feedbackProvider)
            }
        }
        .overlay {
            if showConfetti && settings.confettiEnabled {
                ConfettiView()
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: runner?.run.phase)
        .onAppear(perform: setUp)
        .onChange(of: scenePhase) { _, phase in
            // A rest's timer doesn't fire while the app is suspended.
            if phase == .active { runner?.checkRest() }
        }
        .alert("End session?", isPresented: $isConfirmingEnd) {
            Button("End Session", role: .destructive) { runner?.endSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Completed timers stay in your history.")
        }
        // A sheet that could be swiped away would end a session by accident.
        .interactiveDismissDisabled()
    }

    // MARK: - Phases

    @ViewBuilder
    private func content(_ runner: SessionRunner, feedbackProvider: any FeedbackProvider) -> some View {
        let run = runner.run

        switch run.phase {
        case .finished:
            SessionSummaryView(run: run, onDone: { dismiss() })
                .transition(.opacity)

        case .upNext:
            VStack(spacing: 0) {
                SessionRunHeader(run: run)
                SessionUpNextView(
                    run: run,
                    onStart: {
                        // Each step gets a fresh timer screen, which reports only
                        // changes of these two: start from their initial values.
                        isSwipeDisabled = false
                        showHint = true
                        runner.startStep()
                    },
                    onSkip: { runner.skip() },
                    onEnd: { isConfirmingEnd = true }
                )
            }
            .transition(.opacity)

        case .resting(let until):
            VStack(spacing: 0) {
                SessionRunHeader(run: run)
                SessionRestView(run: run, until: until, onSkip: { runner.skipRest() })
            }
            .transition(.opacity)

        case .running:
            VStack(spacing: 0) {
                SessionRunHeader(run: run)
                if let step = run.currentItem?.step {
                    runningStep(step, runner: runner, feedbackProvider: feedbackProvider)
                }
            }
            .transition(.opacity)
        }
    }

    /// The running step: the timer screen of its kind, which swipes down to end the step.
    private func runningStep(
        _ step: SessionStep, runner: SessionRunner, feedbackProvider: any FeedbackProvider
    ) -> some View {
        VStack(spacing: 0) {
            Text("\(step.exerciseName)\(UISeparator.dot)\(step.kind.rawValue)")
                .font(.headline)
                .padding(.top, 28)

            timer(for: step, runner: runner, feedbackProvider: feedbackProvider)
                // A new identity per start gives every step a fresh timer screen and
                // model, also when a loop runs the same step again.
                .id(runner.stepWorkoutID)

            Text("Swipe down to end this timer")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .opacity(showHint && !isSwipeDisabled ? 1 : 0)
                .padding(.bottom, 12)
        }
        .swipeToDismiss(
            dragOffset: $dragOffset,
            isHandleActive: $isHandleActive,
            onDismiss: { endStep(runner) },
            isDisabled: isSwipeDisabled
        )
        .overlay {
            if !isSwipeDisabled {
                DragHandleView(isActive: isHandleActive, dragOffset: dragOffset)
            }
        }
    }

    @ViewBuilder
    private func timer(
        for step: SessionStep, runner: SessionRunner, feedbackProvider: any FeedbackProvider
    ) -> some View {
        let link = timerScreenLink(for: step, runner: runner)
        // A step keeps its countdown beeps and interval signals, but not its completion
        // sound: the session plays that once, at its end.
        let feedback = StepFeedback(base: feedbackProvider)

        switch step.kind {
        case .emom:
            EMOMTimerView(
                timerModel: EMOMTimerModel(
                    totalDuration: step.durationInterval,
                    intervalCount: step.targetReps ?? 1,
                    timerProvider: timerProvider,
                    feedbackProvider: feedback
                ),
                showRepsInCenter: settings.emomShowRepsInCenter,
                link: link
            )
        case .amrap:
            AMRAPTimerView(
                timerModel: AMRAPTimerModel(
                    totalDuration: step.durationInterval,
                    timerProvider: timerProvider,
                    feedbackProvider: feedback
                ),
                link: link
            )
        case .forTime:
            ForTimeTimerView(
                timerModel: ForTimeTimerModel(
                    targetReps: step.targetReps ?? TimerPreset.defaultForTimeReps,
                    timerProvider: timerProvider,
                    feedbackProvider: feedback
                ),
                link: link
            )
        }
    }

    private var timerProvider: any TimerProvider {
        settings.smoothAnimationsEnabled ? DisplayLinkTimerProvider() : FoundationTimerProvider()
    }

    /// Connects a step's timer screen to the run instead of to a single workout's summary.
    private func timerScreenLink(for step: SessionStep, runner: SessionRunner) -> TimerScreenLink {
        TimerScreenLink(
            onWorkoutCompleted: { runner.stepCompleted($0) },
            onWorkoutStopped: { runner.stepStopped($0) },
            exerciseName: step.exerciseName,
            workoutID: runner.stepWorkoutID,
            autoStart: true,
            // Until the Watch can follow a whole session, its steps stay on the iPhone:
            // started one by one on the Watch, each would be a Health workout of its own.
            startsOnWatch: false,
            isSwipeDisabled: $isSwipeDisabled,
            showHint: $showHint,
            onCleanupForDismiss: { cleanup in timerCleanup = cleanup },
            onDismissRequested: { runner.stepClosed() }
        )
    }

    // MARK: - Actions

    private func setUp() {
        guard runner == nil else { return }
        let feedback: any FeedbackProvider = settings.audioEnabled
            ? settings.completionSoundStyle.makeFeedbackProvider()
            : SilentFeedback()
        feedbackProvider = feedback

        let runner = SessionRunner(name: request.name, elements: request.elements, recorder: workoutRecorder)
        runner.onCompleted = {
            feedback.onWorkoutComplete()
            celebrate()
        }
        self.runner = runner
    }

    /// Swipe-down on a running step: ends that step, not the session.
    private func endStep(_ runner: SessionRunner) {
        // Stops the timer; if the step ran long enough, this reports it as stopped early.
        timerCleanup?()
        timerCleanup = nil
        // Otherwise it was too short to record, and the session just moves on.
        runner.stepClosed()
        dragOffset = 0
        isHandleActive = false
    }

    private func celebrate() {
        showConfetti = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            showConfetti = false
        }
    }
}

#Preview {
    ExerciseRepository.load()
    let burpees = ExerciseRepository.exercise(byName: "6-Count Burpees")?.id
    let squats = ExerciseRepository.exercise(byName: "Squats")?.id
    let loop = SessionLoop(rounds: 2, restSeconds: 20, steps: [
        SessionStep(kind: .amrap, exerciseId: squats, durationInterval: 60, targetReps: nil),
        SessionStep(kind: .forTime, exerciseId: burpees, durationInterval: 0, targetReps: 10)
    ])
    return SessionRunnerView(request: SessionRunRequest(name: "Full Body", elements: [
        .step(SessionStep(kind: .emom, exerciseId: burpees, durationInterval: 60, targetReps: 6)),
        .loop(loop)
    ]))
    .environment(AppSettings())
    .previewTimerSession()
}
