//
//  ShapeLayout.swift
//  Kraftli Timers
//
//  The measurements of a session's shape: how long each segment is drawn.
//

import Foundation

/// Divides a length among a session's segments. Pure functions without any SwiftUI, so
/// the arithmetic can be tested on its own; the views only draw what comes out.
enum ShapeLayout {
    /// The shortest a segment may get before the gaps are given up.
    static let minimumSegmentLength: CGFloat = 1

    /// The gap to leave between segments: `preferred`, or none when the gaps would leave
    /// the segments less than `minimumSegmentLength` each. A session of 20 rounds has
    /// more gaps than a day tile is tall.
    static func spacing(forCount count: Int, in length: CGFloat, preferred: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        let needed = preferred * CGFloat(count - 1) + minimumSegmentLength * CGFloat(count)
        return needed <= length ? preferred : 0
    }

    /// Each segment's share of `length`, in proportion to its duration, after the gaps
    /// between the segments are taken off. Segments without any duration share equally.
    static func lengths(of segments: [SessionEstimate.Segment], in length: CGFloat, spacing: CGFloat) -> [CGFloat] {
        guard !segments.isEmpty else { return [] }
        let available = max(0, length - spacing * CGFloat(segments.count - 1))
        let total = segments.reduce(0) { $0 + $1.seconds }
        guard total > 0 else {
            return segments.map { _ in available / CGFloat(segments.count) }
        }
        return segments.map { available * CGFloat($0.seconds / total) }
    }

    /// A stretch of neighbouring segments: a whole loop, or one segment outside a loop.
    struct Run: Equatable {
        let isLoop: Bool
        let length: CGFloat
    }

    /// Neighbouring segments grouped into runs. A loop's segments form one run, as long
    /// as its segments and the gaps between them.
    static func runs(of segments: [SessionEstimate.Segment], lengths: [CGFloat], spacing: CGFloat) -> [Run] {
        var runs: [(loopID: UUID?, length: CGFloat)] = []
        for (segment, length) in zip(segments, lengths) {
            if let last = runs.last, let loopID = segment.loopID, last.loopID == loopID {
                runs[runs.count - 1].length = last.length + spacing + length
            } else {
                runs.append((segment.loopID, length))
            }
        }
        return runs.map { Run(isLoop: $0.loopID != nil, length: $0.length) }
    }
}
