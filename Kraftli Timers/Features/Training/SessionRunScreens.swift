//
//  SessionRunScreens.swift
//  Kraftli Timers
//
//  The runner's screens around the timers: the header, between steps, the loop rest
//  and the summary (UC-0015).
//

import SwiftUI

// MARK: - Title and progress

/// The line at the top of a runner screen: the session's name between timers, the
/// exercise while a timer runs. It sits where a single timer has its title, and leaves
/// the top of the screen to the status bar and the drag handle.
struct SessionRunTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .padding(.top, 28)
    }
}

/// Where the session is: its shape as a bar, with the position in words below. At the
/// bottom of every runner screen but the summary.
struct SessionProgressStrip: View {
    let run: SessionRun

    /// "Timer 2 of 8", in a loop followed by "· Round 1 of 3".
    private var positionText: String {
        var text = "Timer \(run.timerNumber) of \(run.timerCount)"
        if let loopRound = run.currentLoopRound {
            text += "\(UISeparator.dot)Round \(loopRound.round) of \(loopRound.of)"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 8) {
            SessionShapeBar(segments: run.segments, thickness: 8, position: run.position)
            Text(positionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(positionText)
    }
}

extension SessionRun {
    /// The run's items as the shape bar draws them.
    var segments: [SessionEstimate.Segment] {
        items.map { item in
            switch item.content {
            case .step(let step):
                SessionEstimate.Segment(kind: step.kind, seconds: SessionEstimate.seconds(of: step), loopID: item.loopID)
            case .rest(let seconds):
                SessionEstimate.Segment(kind: nil, seconds: TimeInterval(seconds), loopID: item.loopID)
            }
        }
    }
}

extension SessionStep {
    /// "AMRAP · 4 min", "EMOM · 5 min · 50 reps", "For Time · 30 reps"
    var kindAndSettingsText: String {
        [kind.rawValue, primaryQuantity, kind == .emom ? secondaryQuantity : nil]
            .compactMap { $0 }.joined(separator: UISeparator.dot)
    }
}

extension SessionRun.StepResult {
    /// "5:00 · 50 reps", "4:00 · 9 rounds", "2:43 · 5 rounds · stopped early", "Skipped"
    var text: String {
        guard outcome != .skipped else { return "Skipped" }
        var parts = [String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)]
        if let reps {
            parts.append("\(reps) reps")
        } else if let roundsCounted {
            parts.append("\(roundsCounted) rounds")
        }
        if outcome == .stoppedEarly {
            parts.append("stopped early")
        }
        return parts.joined(separator: UISeparator.dot)
    }
}

/// The timer that ended last, shown between steps and during a rest.
private struct DoneCard: View {
    let result: SessionRun.StepResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.outcome == .skipped ? "forward.circle" : "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.outcome == .skipped ? "SKIPPED" : "DONE")
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                // The name alone: with the kind beside it, a long name is cut off.
                Text(result.step.exerciseName)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if result.outcome != .skipped {
                Text(result.text)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .layoutPriority(1)
            }
        }
        .font(.callout)
        .padding(14)
        .cardStyle(padded: false)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Between steps

/// Between two timers, and before the first: what was done, what comes next, and the
/// buttons to start it, skip it or end the session. The session is paused here.
/// Kept to few elements on purpose: one card, two lines, the progress, the buttons.
struct SessionUpNextView: View {
    let run: SessionRun
    let onStart: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if let result = run.lastResult {
                DoneCard(result: result)
            }

            if let step = run.currentStep {
                // Two lines only: what to do, and in which kind of timer.
                VStack(spacing: 8) {
                    Text(step.exerciseName)
                        .font(.system(size: 40, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    Text(step.kindAndSettingsText)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Up next: \(step.exerciseName), \(step.kindAndSettingsText)")
            }

            SessionProgressStrip(run: run)

            VStack(spacing: 14) {
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)

                HStack(spacing: 12) {
                    Button(action: onSkip) {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .tint(.primary)

                    Button(role: .destructive, action: onEnd) {
                        Text("End Session")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

// MARK: - Loop rest

/// A loop's rest: a ring counting down, and what comes after it.
struct SessionRestView: View {
    let run: SessionRun
    let until: Date
    let onSkip: () -> Void

    /// The rest's full length, for the ring.
    private var restSeconds: TimeInterval {
        if case .rest(let seconds) = run.currentItem?.content { TimeInterval(seconds) } else { 1 }
    }

    var body: some View {
        VStack(spacing: 18) {
            if let result = run.lastResult {
                DoneCard(result: result)
            }

            VStack(spacing: 22) {
                // TimelineView redraws its content on a schedule. The remaining time is
                // computed from `until` on every redraw, so the display can't drift, and
                // it is right again at once after the app was in the background.
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let remaining = max(until.timeIntervalSince(context.date), 0)
                    ZStack {
                        ProgressRing(
                            size: 240,
                            lineWidth: 12,
                            progress: remaining / restSeconds,
                            color: Color(UIColor.systemGray),
                            backgroundColor: Color(UIColor.systemGray5),
                            rotationDegrees: -90
                        )
                        VStack(spacing: 2) {
                            Text("REST")
                                .font(.footnote.weight(.semibold))
                                .tracking(1)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%d:%02d", Int(remaining.rounded(.up)) / 60, Int(remaining.rounded(.up)) % 60))
                                .font(.system(size: 64, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 240, height: 240)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rest")
                    .accessibilityValue("\(Int(remaining.rounded(.up))) seconds left")
                }

                if let step = run.currentStep {
                    VStack(spacing: 4) {
                        Text("Then \(step.exerciseName)")
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(step.kindAndSettingsText)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxHeight: .infinity)

            SessionProgressStrip(run: run)

            VStack(spacing: 14) {
                Button(action: onSkip) {
                    Text("Skip Rest")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.primary)

                Text("Counts as training time")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

// MARK: - Summary

/// The session's summary: total time, the Watch's heart rate and calories, and what
/// every timer came to.
struct SessionSummaryView: View {
    let run: SessionRun
    /// True when the Watch tracked the session.
    let trackedByWatch: Bool
    /// The Watch's figures for the session's Health workout, once they arrived.
    let watchData: WorkoutSessionEndedMessage?
    let onDone: () -> Void

    /// The Watch's figures are expected, and shown as "--" until they arrive. Not when
    /// nothing was recorded: the Watch saved nothing then either.
    private var expectsWatchData: Bool {
        trackedByWatch && run.recordedCount > 0
    }

    private var hasHealthData: Bool {
        guard let watchData else { return false }
        return watchData.averageHeartRate != nil || watchData.maxHeartRate != nil || watchData.activeCalories != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Summary")
                    .font(.title.weight(.bold))
                Text("\(run.name)\(UISeparator.dot)\(run.recordedCount) of \(run.timerCount) timers")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            ScrollView {
                VStack(spacing: 12) {
                    tiles

                    if !run.results.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(run.results.enumerated()), id: \.offset) { offset, result in
                                if let heading = roundHeading(at: offset) {
                                    Text(heading)
                                        .font(.caption.weight(.bold))
                                        .tracking(0.6)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 10)
                                }
                                ResultRow(result: result)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .cardStyle(padded: false)
                    }

                    if !trackedByWatch {
                        Text("Connect Apple Watch for heart rate and calories")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                if hasHealthData {
                    Button(action: HealthApp.open) {
                        Label("Open Health", systemImage: "heart.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.primary)
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.4), value: watchData)
    }

    /// Total Time alone, or with the Watch's three figures in a grid of two columns.
    @ViewBuilder
    private var tiles: some View {
        let totalTime = SummaryTile(title: "Total Time", value: run.totalTime.formatted)
        if expectsWatchData {
            // LazyVGrid lays its children out in columns; two flexible ones share the width.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                totalTime
                SummaryTile(title: "Active Calories", number: watchData?.activeCalories, unit: "kcal")
                SummaryTile(title: "Avg Heart Rate", number: watchData?.averageHeartRate, unit: "bpm")
                SummaryTile(title: "Max Heart Rate", number: watchData?.maxHeartRate, unit: "bpm")
            }
        } else {
            totalTime
        }
    }

    /// "ROUND 2" above the first timer of each round of a loop; `nil` elsewhere.
    private func roundHeading(at offset: Int) -> String? {
        let result = run.results[offset]
        guard let round = result.loopRound else { return nil }
        let loopID = run.items[result.index].loopID
        if offset > 0 {
            let previous = run.results[offset - 1]
            if previous.loopRound == round, run.items[previous.index].loopID == loopID {
                return nil
            }
        }
        return "ROUND \(round)"
    }
}

/// One figure of the summary: a title and its value, "--" while the value is pending.
private struct SummaryTile: View {
    let title: String
    let value: String
    var unit: String?

    init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    /// A whole number from the Watch, cut off like in a single workout's summary; `nil`
    /// shows "--".
    init(title: String, number: Double?, unit: String) {
        self.title = title
        self.value = number.map { "\(Int($0))" } ?? "--"
        self.unit = unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// One timer of the summary: kind colour, exercise, result.
private struct ResultRow: View {
    let result: SessionRun.StepResult

    private var isSkipped: Bool { result.outcome == .skipped }

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isSkipped ? Color(UIColor.systemGray3) : result.step.kind.color)
                .frame(width: 10, height: 10)
            Text(result.step.exerciseName)
                .foregroundStyle(isSkipped ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(result.text)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .layoutPriority(1)
        }
        .font(.callout)
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
    }
}
