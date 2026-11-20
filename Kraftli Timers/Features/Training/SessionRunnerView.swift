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
    @Environment(TimerSessionController.self) private var timerSession
    @Environment(PhoneMessageCoordinator.self) private var messageCoordinator

    /// Created in `onAppear`, because it needs the recorder from the environment.
    @State private var runner: SessionRunner?
    /// Plays the sounds of every step and, once, the session's completion sound.
    @State private var feedbackProvider: (any FeedbackProvider)?

    /// The Watch's figures for the session's Health workout, for the summary.
    @State private var watchData: WorkoutSessionEndedMessage?

    @State private var isConfirmingEnd = false
    @State private var showConfetti = false

    // The running step's swipe-down, as in `TimerRunnerView`.
    @State private var dragOffset: CGFloat = 0
    @State private var isHandleActive = false
    /// The state shared with the running step's timer screen.
    @State private var chrome = TimerChrome()

    var body: some View {
        // A NavigationStack only for its bar: the title sits where a single timer has
        // it (`TimerRunnerView`), and the drag handle comes out below it by itself.
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                if let runner, let feedbackProvider {
                    content(runner, feedbackProvider: feedbackProvider)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(runner?.run.phase == .finished ? .hidden : .visible, for: .navigationBar)
        }
        .confetti(isPresented: $showConfetti)
        .animation(.easeInOut(duration: 0.3), value: runner?.run.phase)
        .onAppear(perform: setUp)
        .onChange(of: runner?.stepWorkoutID) {
            // Each step gets a fresh timer screen: start it from a fresh chrome.
            chrome.reset()
        }
        .onChange(of: timerSession.renderedState?.owner) { _, owner in
            // The first step's owner holds the session's Health workout from then on.
            if let owner, let runner, timerSession.follows(runner.stepWorkoutID) {
                runner.stepOwned(by: owner)
            }
        }
        // The Watch reports the session's Health workout under the run's ID.
        .onChange(of: messageCoordinator.lastWorkoutSessionEnded) { _, message in
            guard let message, let runner, message.correlationID == runner.runID else { return }
            watchData = message
            // Normally this answers the session's end. If the session is still going, the
            // athlete ended it on the Watch: it ends here too (ADR-0012 rule 4).
            endSessionEndedOnWatch(runner)
        }
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
            SessionSummaryView(
                run: run,
                trackedByWatch: runner.healthOwner == .watch,
                watchData: watchData,
                onDone: { dismiss() }
            )
                .transition(.opacity)

        case .upNext:
            SessionUpNextView(
                run: run,
                onStart: { runner.startStep() },
                onSkip: { runner.skip() },
                onEnd: { isConfirmingEnd = true }
            )
            .transition(.opacity)

        case .resting(let until):
            SessionRestView(run: run, until: until)
                // Swiping down ends what is running now: here the rest, as it ends
                // the timer on a running step.
                .endsBySwipe(
                    named: "Skip rest", dragOffset: $dragOffset, isHandleActive: $isHandleActive
                ) {
                    runner.skipRest()
                    resetSwipe()
                }
                .transition(.opacity)

        case .running:
            if let step = run.currentItem?.step {
                runningStep(step, runner: runner, feedbackProvider: feedbackProvider)
                    .transition(.opacity)
            }
        }
    }

    /// The running step: the timer screen of its kind, which swipes down to end the step.
    private func runningStep(
        _ step: SessionStep, runner: SessionRunner, feedbackProvider: any FeedbackProvider
    ) -> some View {
        VStack(spacing: 0) {
            KindTimerView(
                config: step.timerConfig,
                // A step keeps its countdown beeps and interval signals, but not its
                // completion sound: the session plays that once, at its end.
                feedbackProvider: StepFeedback(base: feedbackProvider),
                link: timerScreenLink(for: runner)
            )
                // A new identity per start gives every step a fresh timer screen and
                // model, also when a loop runs the same step again.
                .id(runner.stepWorkoutID)

            SessionSwipeHint(
                text: "Swipe down to end this timer", isVisible: chrome.showHint && !chrome.isSwipeDisabled
            )
                .padding(.bottom, 12)
        }
        .endsBySwipe(
            named: "End timer", dragOffset: $dragOffset, isHandleActive: $isHandleActive,
            isDisabled: chrome.isSwipeDisabled
        ) {
            endStep(runner)
        }
    }

    /// Connects a step's timer screen to the run instead of to a single workout's summary.
    private func timerScreenLink(for runner: SessionRunner) -> TimerScreenLink {
        TimerScreenLink(
            onWorkoutCompleted: { runner.stepCompleted($0) },
            onWorkoutStopped: { runner.stepStopped($0) },
            workoutID: runner.stepWorkoutID,
            autoStart: true,
            startsOnWatch: runner.startsStepsOnWatch,
            session: runner.context,
            chrome: chrome,
            // The session's progress, under the timer's total time.
            footer: AnyView(SessionProgressBar(run: runner.run)),
            onDismissRequested: { runner.stepClosed() }
        )
    }

    // MARK: - Actions

    private func setUp() {
        guard runner == nil else { return }
        let feedback = settings.makeFeedbackProvider()
        feedbackProvider = feedback

        let timerSession = timerSession
        let runner = SessionRunner(
            name: request.name,
            elements: request.elements,
            recorder: workoutRecorder,
            sendStatus: { timerSession.send($0) }
        )
        runner.onCompleted = {
            feedback.onWorkoutComplete()
            celebrate()
        }
        self.runner = runner
    }

    /// Swipe-down on a running step: ends that step, not the session.
    private func endStep(_ runner: SessionRunner) {
        // Stops the timer; if the step ran long enough, this reports it as stopped early.
        chrome.endWorkout()
        // Otherwise it was too short to record, and the session just moves on.
        runner.stepClosed()
        resetSwipe()
    }

    /// Puts the swipe back to rest for the next screen that uses it.
    private func resetSwipe() {
        dragOffset = 0
        isHandleActive = false
    }

    /// The session's name between timers and during a rest, "Push-ups · AMRAP" while a
    /// timer runs.
    private var navigationTitle: String {
        guard let run = runner?.run else { return request.name }
        if run.phase == .running, let step = run.currentItem?.step {
            return "\(step.exerciseName)\(UISeparator.dot)\(step.kind.rawValue)"
        }
        return run.name
    }

    /// The Watch saved the session's Health workout while the session was still going:
    /// a running step ends as after a swipe-down, then the session ends.
    private func endSessionEndedOnWatch(_ runner: SessionRunner) {
        guard runner.run.phase != .finished else { return }
        isConfirmingEnd = false
        if runner.run.phase == .running {
            endStep(runner)
        }
        runner.endSession()
    }

    private func celebrate() {
        showConfetti = true
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
    .environment(PhoneMessageCoordinator())
    .previewTimerSession()
}
