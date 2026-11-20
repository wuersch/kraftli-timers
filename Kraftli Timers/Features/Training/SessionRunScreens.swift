//
//  SessionRunScreens.swift
//  Kraftli Timers
//
//  The runner's screens around the timers: between steps, the loop rest and the
//  summary, and the dots that show the position on all of them (UC-0015).
//

import SwiftUI

// MARK: - Position

/// Where the session is, as quietly as a page indicator: one small dot per timer, gray
/// for those behind, white for the current one, dark for those to come. At the bottom
/// of every runner screen but the summary.
///
/// A session with more timers than fit as dots says it in words: "14 of 40".
struct SessionDots: View {
    let run: SessionRun

    static let mostDots = 12

    private var positionText: String {
        "\(run.timerNumber) of \(run.timerCount)"
    }

    var body: some View {
        Group {
            if run.timerCount <= Self.mostDots {
                HStack(spacing: 8) {
                    ForEach(1...max(run.timerCount, 1), id: \.self) { number in
                        Circle()
                            .fill(color(of: number))
                            .frame(width: 6, height: 6)
                    }
                }
            } else {
                Text(positionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer \(positionText)")
    }

    private func color(of number: Int) -> Color {
        if number < run.timerNumber {
            Color(UIColor.systemGray)
        } else if number == run.timerNumber {
            .primary
        } else {
            Color(UIColor.systemGray4)
        }
    }
}

/// The line under a runner screen's centre that says how to end what is running, in
/// the place and look of the other hints.
struct SessionSwipeHint: View {
    let text: String
    var isVisible = true

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.gray.opacity(0.6))
            .opacity(isVisible ? 1 : 0)
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

extension SessionRun.StepResult {
    /// "Jumping Jacks done · 5:00 · 50 reps", "Squats skipped"
    var doneLine: String {
        outcome == .skipped
            ? "\(step.exerciseName) skipped"
            : "\(step.exerciseName) done\(UISeparator.dot)\(text)"
    }
}

// MARK: - Between steps

/// Between two timers, and before the first: what comes next, what was just done, and
/// the buttons to start it, skip it or end the session. The session is paused here.
///
/// Kept quiet on purpose: two lines in the centre, one gray line, the dots, and only
/// "Start" drawn as a button.
struct SessionUpNextView: View {
    let run: SessionRun
    let onStart: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            if let step = run.currentStep {
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

            if let result = run.lastResult {
                Text(result.doneLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            SessionDots(run: run)

            VStack(spacing: 6) {
                // The quiet form of a main action, as on the Training tab: a tinted
                // label on a wash of the tint.
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.accentColor)

                // Plain text, so the two ways out don't compete with Start.
                HStack(spacing: 0) {
                    Button("Skip", action: onSkip)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Button("End Session", action: onEnd)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

// MARK: - Loop rest

/// A loop's rest: a ring counting down, what comes after it, and the dots. No buttons:
/// like a running timer, a rest is cut short by swiping down.
struct SessionRestView: View {
    let run: SessionRun
    let until: Date

    /// The rest's full length, for the ring.
    private var restSeconds: TimeInterval {
        if case .rest(let seconds) = run.currentItem?.content { TimeInterval(seconds) } else { 1 }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 18) {
                // TimelineView redraws its content on a schedule. The remaining time is
                // computed from `until` on every redraw, so the display can't drift, and
                // it is right again at once after the app was in the background.
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let remaining = max(until.timeIntervalSince(context.date), 0)
                    ZStack {
                        ProgressRing(
                            size: 260,
                            lineWidth: 10,
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
                            Text(TimeInterval(remaining.rounded(.up)).formatted)
                                .font(.system(size: 64, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 260, height: 260)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rest")
                    .accessibilityValue("\(Int(remaining.rounded(.up))) seconds left")
                }

                if let step = run.currentStep {
                    Text("Then \(step.exerciseName)\(UISeparator.dot)\(step.kindAndSettingsText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxHeight: .infinity)

            SessionSwipeHint(text: "Swipe down to skip the rest")
            SessionDots(run: run)
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
