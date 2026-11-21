//
//  WatchSessionView.swift
//  Kraftli Timers Watch App
//
//  What the Watch shows of a training session outside its timers: what is up next,
//  a loop's rest, and that the session is done (UC-0015, ADR-0012).
//

import SwiftUI

/// The Watch's view of a session's run between its steps.
///
/// The Watch only follows a session: everything here is drawn from the last
/// `SessionStatus` the iPhone sent, and the next timer is started on the iPhone. A step's
/// timer covers this view while it runs (`WatchWorkoutScreen`, presented as a cover).
///
/// The one thing the athlete can do here is end the workout on the Watch, on a page to
/// the left like a timer's controls. It is the way out when the iPhone is out of reach,
/// because otherwise only the iPhone's "finished" ends the Health workout held here.
struct WatchSessionView: View {
    let follower: WatchSessionFollower

    private enum Page {
        case controls
        case progress
    }

    @State private var page: Page = .progress

    var body: some View {
        Group {
            if let finished = follower.finishedRun {
                doneView(finished)
            } else {
                TabView(selection: $page) {
                    controlsPage
                        .tag(Page.controls)
                    progressPage
                        .tag(Page.progress)
                }
                .tabViewStyle(.page)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressPage: some View {
        if let status = follower.status {
            VStack(alignment: .leading, spacing: 8) {
                switch status.phase {
                case .upNext:
                    centered {
                        if let count = status.loopStepCount, let rounds = status.loopRounds {
                            loopInfo(rounds: rounds, stepCount: count, status: status)
                        } else {
                            stepInfo(heading: "UP NEXT", status: status)
                        }
                    }
                    footer("Start on iPhone")
                case .running:
                    centered { stepInfo(heading: "NOW", status: status) }
                    footer("Running on iPhone")
                case .resting(let until):
                    centered {
                        if status.isChangeover == true {
                            // Two seconds before a loop's next timer starts by itself.
                            stepInfo(heading: "NEXT", status: status)
                        } else {
                            restInfo(until: until, status: status)
                        }
                    }
                case .finished:
                    // Not reached: a finished run is released or shown as done.
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
        } else {
            // Holding the run, but the iPhone hasn't reported since.
            VStack(spacing: 6) {
                Text(follower.held?.name ?? "Session")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("Continue on iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
        }
    }

    /// "UP NEXT", the exercise, "AMRAP · 4 min" and, in a loop, "Round 1 of 3".
    private func stepInfo(heading: String, status: SessionStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            if let step = status.step {
                Text(step.exerciseName)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(step.settingsText)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            if let round = status.loopRound, let rounds = status.loopRounds {
                Text("Round \(round) of \(rounds)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Before a loop: "UP NEXT", "3 × 5 timers" and "First: Pull-ups". The loop's timers
    /// are listed on the iPhone, where it is started.
    private func loopInfo(rounds: Int, stepCount: Int, status: SessionStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("UP NEXT")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text("\(rounds) × \(stepCount) \(stepCount == 1 ? "timer" : "timers")")
                .font(.system(size: 24, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let step = status.step {
                Text("First: \(step.exerciseName)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Up next: \(rounds) rounds of \(stepCount) \(stepCount == 1 ? "timer" : "timers")"
                + (status.step.map { ", first \($0.exerciseName)" } ?? "")
        )
    }

    /// "REST" with the countdown, and the timer that starts by itself after it.
    private func restInfo(until: Date, status: SessionStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("REST")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            // A Text built from a time range counts down by itself, driven by the
            // system: no timer of our own, and it keeps going on the dimmed display.
            Text(timerInterval: Date.now...max(until, Date.now), countsDown: true)
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
            if let step = status.step {
                Text("Then \(step.exerciseName)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The lines of a phase with the session's shape bar under them, centred together
    /// in the space above the footer. The bar is a detail below the text, as on the
    /// iPhone, and stays clear of the clock at the top.
    private func centered(@ViewBuilder _ lines: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            lines()
            if let status = follower.status {
                WatchSessionShapeBar(segments: status.shape, position: status.position)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Controls

    private var controlsPage: some View {
        VStack(spacing: 6) {
            Button {
                follower.endOnWatch()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(0.25))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End")

            Text("End")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Saves the workout on this Watch")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Done

    private func doneView(_ run: SessionContext) -> some View {
        VStack(spacing: 8) {
            Text("DONE")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
            Text(run.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Button("End") {
                follower.dismissFinished()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Shape Bar

/// The session's shape as a thin bar: one segment per timer and rest, sized by duration.
/// Segments already behind are dimmed. The Watch's counterpart of the iPhone's
/// `SessionShapeBar`, in the same look, drawn from what the status carries.
private struct WatchSessionShapeBar: View {
    let segments: [SessionStatus.Segment]
    let position: Int

    private let thickness: CGFloat = 4
    private let spacing: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let total = segments.reduce(0) { $0 + $1.seconds }
            // With many segments the gaps would use up the bar: leave them out then.
            let gap = CGFloat(segments.count) * (spacing + 1) <= proxy.size.width ? spacing : 0
            let available = max(0, proxy.size.width - gap * CGFloat(max(segments.count - 1, 0)))

            HStack(spacing: gap) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    let share = total > 0 ? segment.seconds / total : 1 / Double(max(segments.count, 1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segment.kind?.color ?? Color.gray.opacity(0.6))
                        .opacity(index < position ? 0.3 : 1)
                        .frame(width: available * share, height: thickness)
                }
            }
        }
        .frame(height: thickness)
        .accessibilityHidden(true)
    }
}

// MARK: - Text

private extension TimerConfig {
    /// "AMRAP · 4 min", "EMOM · 5 min", "For Time · 30 reps"
    var settingsText: String {
        let quantity: String? = if kind.hasFixedDuration {
            totalDuration?.durationText
        } else {
            targetReps.map { "\($0) reps" }
        }
        return [kind.rawValue, quantity].compactMap { $0 }.joined(separator: UISeparator.dot)
    }
}

// MARK: - Previews

#Preview("Up next") {
    let follower = WatchSessionFollower(
        pauseHealthSession: {}, resumeHealthSession: {}, saveHealthSession: { _ in }, discardHealthSession: {}
    )
    let context = SessionContext(runID: UUID(), name: "Full Body")
    follower.hold(context)
    var status = SessionStatus(runID: context.runID, name: context.name, sequence: 1, phase: .upNext)
    status.step = TimerConfig(kind: .amrap, totalDuration: 240, intervalCount: nil, exerciseName: "Push-ups", targetReps: nil)
    status.loopRound = 1
    status.loopRounds = 3
    status.shape = [
        .init(kind: .emom, seconds: 300), .init(kind: .amrap, seconds: 240),
        .init(kind: .forTime, seconds: 120), .init(kind: nil, seconds: 60),
        .init(kind: .amrap, seconds: 240), .init(kind: .forTime, seconds: 120)
    ]
    status.position = 1
    follower.receive(status)
    return WatchSessionView(follower: follower)
}

#Preview("Before a loop") {
    let follower = WatchSessionFollower(
        pauseHealthSession: {}, resumeHealthSession: {}, saveHealthSession: { _ in }, discardHealthSession: {}
    )
    let context = SessionContext(runID: UUID(), name: "Little Torture")
    follower.hold(context)
    var status = SessionStatus(runID: context.runID, name: context.name, sequence: 1, phase: .upNext)
    status.step = TimerConfig(kind: .forTime, totalDuration: nil, intervalCount: nil, exerciseName: "Pull-ups", targetReps: 5)
    status.loopRound = 1
    status.loopRounds = 3
    status.loopStepCount = 5
    status.shape = [.init(kind: .amrap, seconds: 60)] + Array(repeating: .init(kind: .forTime, seconds: 60), count: 5)
    status.position = 1
    follower.receive(status)
    return WatchSessionView(follower: follower)
}

#Preview("Changeover") {
    let follower = WatchSessionFollower(
        pauseHealthSession: {}, resumeHealthSession: {}, saveHealthSession: { _ in }, discardHealthSession: {}
    )
    let context = SessionContext(runID: UUID(), name: "Little Torture")
    follower.hold(context)
    var status = SessionStatus(
        runID: context.runID, name: context.name, sequence: 1, phase: .resting(until: .now.addingTimeInterval(2))
    )
    status.step = TimerConfig(kind: .forTime, totalDuration: nil, intervalCount: nil, exerciseName: "Lunges", targetReps: 12)
    status.loopRound = 2
    status.loopRounds = 3
    status.isChangeover = true
    status.shape = Array(repeating: .init(kind: .forTime, seconds: 60), count: 6)
    status.position = 3
    follower.receive(status)
    return WatchSessionView(follower: follower)
}
