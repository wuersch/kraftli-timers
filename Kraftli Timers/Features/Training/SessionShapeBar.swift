//
//  SessionShapeBar.swift
//  Kraftli Timers
//
//  A session drawn as a bar of segments: its shape.
//

import SwiftUI

/// Draws a session as one segment per timer in running order, coloured by kind and
/// sized by duration. The same shape stands for a session wherever it appears: in the
/// week strip (vertical), on cards and in the editor (horizontal).
struct SessionShapeBar: View {
    let segments: [SessionEstimate.Segment]
    var axis: Axis = .horizontal
    /// The bar's thickness when horizontal. A vertical bar fills the width it is given.
    var thickness: CGFloat = 8
    /// Draws a bracket under each loop. Horizontal bars only.
    var showsLoops = false

    private let spacing: CGFloat = 2
    private let bracketHeight: CGFloat = 6

    var body: some View {
        // GeometryReader hands its content the size it was offered, which is what the
        // segment lengths have to be computed from.
        GeometryReader { proxy in
            let length = axis == .horizontal ? proxy.size.width : proxy.size.height
            let lengths = Self.lengths(of: segments, in: length, spacing: spacing)

            if axis == .horizontal {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: spacing) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                            RoundedRectangle(cornerRadius: min(3, thickness / 2))
                                .fill(Self.color(of: segment))
                                .frame(width: lengths[index], height: thickness)
                        }
                    }
                    if showsLoops {
                        HStack(spacing: spacing) {
                            ForEach(Array(Self.runs(of: segments, lengths: lengths, spacing: spacing).enumerated()),
                                    id: \.offset) { _, run in
                                LoopBracket()
                                    .stroke(.secondary, lineWidth: 1)
                                    .opacity(run.isLoop ? 1 : 0)
                                    .frame(width: run.length, height: bracketHeight)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: spacing) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Self.color(of: segment))
                            .frame(height: lengths[index])
                    }
                }
            }
        }
        .frame(height: axis == .horizontal ? thickness + (showsLoops ? bracketHeight + 3 : 0) : nil)
        .accessibilityHidden(true)
    }

    static func color(of segment: SessionEstimate.Segment) -> Color {
        segment.kind?.color ?? Color(UIColor.systemGray3)
    }

    /// Each segment's share of `length`, in proportion to its duration, after the gaps
    /// between the segments are taken off.
    static func lengths(of segments: [SessionEstimate.Segment], in length: CGFloat, spacing: CGFloat) -> [CGFloat] {
        guard !segments.isEmpty else { return [] }
        let available = max(0, length - spacing * CGFloat(segments.count - 1))
        let total = segments.reduce(0) { $0 + $1.seconds }
        guard total > 0 else {
            return segments.map { _ in available / CGFloat(segments.count) }
        }
        return segments.map { available * CGFloat($0.seconds / total) }
    }

    /// Neighbouring segments grouped into runs: a loop's segments form one run, as long
    /// as the segments and the gaps between them.
    static func runs(
        of segments: [SessionEstimate.Segment],
        lengths: [CGFloat],
        spacing: CGFloat
    ) -> [(isLoop: Bool, length: CGFloat)] {
        var runs: [(loopID: UUID?, length: CGFloat)] = []
        for (index, segment) in segments.enumerated() {
            if let last = runs.last, last.loopID == segment.loopID, segment.loopID != nil {
                runs[runs.count - 1].length = last.length + spacing + lengths[index]
            } else {
                runs.append((segment.loopID, lengths[index]))
            }
        }
        return runs.map { ($0.loopID != nil, $0.length) }
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
        SessionShapeBar(segments: segments, axis: .vertical)
            .frame(width: 20, height: 80)
    }
    .padding()
}
