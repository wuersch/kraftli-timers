//
//  SessionBlockViews.swift
//  Kraftli Timers
//
//  The blocks of the session editor: a timer block, and the pieces of a loop block.
//

import SwiftUI

/// One timer of a session, tinted by its kind: the exercise as the headline, and what
/// defines the timer on the trailing edge.
struct StepBlockView: View {
    let step: SessionStep

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(step.kind.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(step.kind.color)
                Text(step.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 1) {
                Text(step.primaryQuantity)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                if let secondary = step.secondaryQuantity {
                    Text(secondary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(step.kind.color.opacity(0.25))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.kind.rawValue), \(step.exerciseName), \(step.quantityText)")
    }
}

/// The rail on a loop's leading edge: it spans the loop's timers and names the rounds.
struct LoopRailView: View {
    let rounds: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "repeat")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(rounds)×")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxHeight: .infinity)
        .frame(width: 56)
        .background(Color(UIColor.systemGray4))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Repeat \(rounds) times")
        .accessibilityHint("Changes rounds and rest")
    }
}

/// The row at the end of a loop that names the rest between its rounds.
struct LoopRestRowView: View {
    let loop: SessionLoop

    var body: some View {
        HStack {
            Text("Rest between rounds")
                .foregroundStyle(.secondary)
            Spacer()
            Text(loop.restText)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(Color(UIColor.systemGray5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A dashed outline button for adding something: "+ Timer", "+ Loop".
struct DashedButtonStyle: ButtonStyle {
    var isHighlighted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isHighlighted ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

/// A message for something that keeps the session from being saved.
struct IssueLabel: View {
    let issue: SessionDraft.Issue

    var body: some View {
        Label(issue.message, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 2) {
        StepBlockView(step: SessionStep(kind: .emom, exerciseId: nil, durationInterval: 300, targetReps: 50))
        HStack(spacing: 2) {
            LoopRailView(rounds: 3)
            VStack(spacing: 2) {
                StepBlockView(step: SessionStep(kind: .amrap, exerciseId: nil, durationInterval: 240, targetReps: nil))
                StepBlockView(step: SessionStep(kind: .forTime, exerciseId: nil, durationInterval: 0, targetReps: 30))
                LoopRestRowView(loop: SessionLoop(rounds: 3, restSeconds: 60))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding()
}
