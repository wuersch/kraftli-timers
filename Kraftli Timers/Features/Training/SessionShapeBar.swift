//
//  SessionShapeBar.swift
//  Kraftli Timers
//
//  A session drawn as a bar of segments: its shape, lying and upright.
//

import SwiftUI

/// A session drawn as a horizontal bar: one segment per timer in running order, coloured
/// by kind and sized by duration. The same shape stands for a session wherever it
/// appears; `SessionShapeColumn` is its upright form for the week strip.
struct SessionShapeBar: View {
    let segments: [SessionEstimate.Segment]
    var thickness: CGFloat = 8
    /// Draws a bracket under each loop.
    var showsLoops = false
    /// While the session runs: the index of the segment it is at. The segments before
    /// it are dimmed. `nil` draws the plain shape.
    var position: Int?

    private let preferredSpacing: CGFloat = 2
    private let bracketHeight: CGFloat = 6
    private let bracketGap: CGFloat = 3

    var body: some View {
        // GeometryReader hands its content the size it was offered, which is what the
        // segment lengths have to be computed from.
        GeometryReader { proxy in
            let spacing = ShapeLayout.spacing(
                forCount: segments.count, in: proxy.size.width, preferred: preferredSpacing
            )
            let lengths = ShapeLayout.lengths(of: segments, in: proxy.size.width, spacing: spacing)

            VStack(alignment: .leading, spacing: bracketGap) {
                HStack(spacing: spacing) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        RoundedRectangle(cornerRadius: min(3, thickness / 2))
                            .fill(segment.color)
                            .opacity(position.map { index < $0 ? 0.3 : 1 } ?? 1)
                            .frame(width: lengths[index], height: thickness)
                    }
                }
                if showsLoops {
                    HStack(spacing: spacing) {
                        let runs = ShapeLayout.runs(of: segments, lengths: lengths, spacing: spacing)
                        ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                            LoopBracket()
                                .stroke(.secondary, lineWidth: 1)
                                .opacity(run.isLoop ? 1 : 0)
                                .frame(width: run.length, height: bracketHeight)
                        }
                    }
                }
            }
        }
        .frame(height: thickness + (showsLoops ? bracketHeight + bracketGap : 0))
        .accessibilityHidden(true)
    }
}

/// A session drawn upright, top to bottom, filling the space it is given: the shape in
/// a day tile of the week strip.
struct SessionShapeColumn: View {
    let segments: [SessionEstimate.Segment]

    private let preferredSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let spacing = ShapeLayout.spacing(
                forCount: segments.count, in: proxy.size.height, preferred: preferredSpacing
            )
            let lengths = ShapeLayout.lengths(of: segments, in: proxy.size.height, spacing: spacing)

            VStack(spacing: spacing) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    RoundedRectangle(cornerRadius: min(2, lengths[index] / 2))
                        .fill(segment.color)
                        .frame(height: lengths[index])
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension SessionEstimate.Segment {
    /// The colour of the segment's kind; gray for a rest.
    var color: Color {
        kind?.color ?? Color(UIColor.systemGray3)
    }
}

/// A bracket opening upwards, drawn under a loop's segments.
private struct LoopBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(4, rect.height)
        path.move(to: CGPoint(x: rect.minX + 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 0.5, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 0.5 + radius, y: rect.maxY - 0.5),
            control: CGPoint(x: rect.minX + 0.5, y: rect.maxY - 0.5)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 0.5 - radius, y: rect.maxY - 0.5))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 0.5, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX - 0.5, y: rect.maxY - 0.5)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.minY))
        return path
    }
}

#Preview {
    let loopID = UUID()
    let segments: [SessionEstimate.Segment] = [
        .init(kind: .emom, seconds: 300, loopID: nil),
        .init(kind: .amrap, seconds: 240, loopID: loopID),
        .init(kind: .forTime, seconds: 250, loopID: loopID),
        .init(kind: nil, seconds: 60, loopID: loopID),
        .init(kind: .amrap, seconds: 240, loopID: loopID),
        .init(kind: .forTime, seconds: 250, loopID: loopID),
        .init(kind: .amrap, seconds: 300, loopID: nil)
    ]
    return VStack(spacing: 24) {
        SessionShapeBar(segments: segments, thickness: 26, showsLoops: true)
        SessionShapeBar(segments: segments)
        SessionShapeColumn(segments: segments)
            .frame(width: 20, height: 80)
    }
    .padding()
}
