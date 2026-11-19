//
//  SessionCards.swift
//  Kraftli Timers
//
//  How a session is shown in the Training tab: as a compact card, and in full for
//  the selected day.
//

import SwiftUI

/// A session in a list: its name, its shape and a line of detail.
struct SessionCardContent: View {
    let session: TrainingSession
    /// Text after the estimated length, such as the days it is planned on.
    var detail: String?

    var body: some View {
        let estimate = SessionEstimate(of: session.elements)

        VStack(alignment: .leading, spacing: 7) {
            Text(session.name)
                .font(.headline)
                .foregroundStyle(.primary)
            SessionShapeBar(segments: estimate.segments, thickness: 6)
            Text(
                [estimate.lengthText, detail]
                    .compactMap { $0 }
                    .joined(separator: UISeparator.dot)
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The session planned on the selected day, in full: name, estimated length, shape and
/// every timer.
struct SelectedDayCard: View {
    let title: String
    let session: TrainingSession
    let onChange: () -> Void
    let onStart: () -> Void

    var body: some View {
        // Decoded and estimated once per redraw; the lines below all read from these.
        let elements = session.elements
        let estimate = SessionEstimate(of: elements)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Change", action: onChange)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }

            Text(session.name)
                .font(.title.weight(.bold))
                .padding(.top, 4)
            Text(estimate.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            SessionShapeBar(segments: estimate.segments, thickness: 26, showsLoops: true)
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(elements) { element in
                    switch element {
                    case .step(let step):
                        TimerRow(color: step.kind.color, name: step.exerciseName, quantity: step.quantityText)
                    case .loop(let loop):
                        HStack(spacing: 10) {
                            Text("\(loop.rounds)×")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .frame(width: 34)
                                .frame(maxHeight: .infinity)
                                .background(Color(UIColor.systemGray4), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(loop.steps) { step in
                                    TimerRow(
                                        color: step.kind.color, name: step.exerciseName, quantity: step.quantityText
                                    )
                                }
                                if loop.restSeconds > 0 {
                                    TimerRow(
                                        color: Color(UIColor.systemGray3), name: "Rest", quantity: loop.restText,
                                        isRest: true
                                    )
                                }
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                    }
                }
            }

            // `.bordered` with the tint is the quiet form of a main action: tinted
            // label on a wash of the tint, instead of `.borderedProminent`'s solid fill.
            Button(action: onStart) {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .padding(.top, 14)
            .accessibilityLabel("Start \(session.name)")
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// One timer of the selected day's session: kind colour, exercise, quantity.
private struct TimerRow: View {
    let color: Color
    let name: String
    let quantity: String
    var isRest = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .foregroundStyle(isRest ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(quantity)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                // The quantity keeps its width; a long exercise name is the one to shorten.
                .layoutPriority(1)
        }
        .font(.callout)
        .frame(minHeight: 30)
        .accessibilityElement(children: .combine)
    }
}
