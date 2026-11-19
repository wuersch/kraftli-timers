//
//  ShapeLayoutTests.swift
//  Kraftli TimersTests
//
//  The measurements of a session's shape.
//

import Foundation
import Testing
@testable import Kraftli_Timers

@MainActor
struct ShapeLayoutTests {
    private func segment(_ seconds: TimeInterval, loop: UUID? = nil) -> SessionEstimate.Segment {
        SessionEstimate.Segment(kind: .amrap, seconds: seconds, loopID: loop)
    }

    // MARK: - Lengths

    @Test func lengths_areInProportionToTheDurations_afterTheGaps() {
        let lengths = ShapeLayout.lengths(of: [segment(60), segment(180)], in: 102, spacing: 2)

        // 102 minus one gap of 2 leaves 100, shared 1 : 3.
        #expect(lengths == [25, 75])
    }

    @Test func segmentsWithoutDuration_shareEqually() {
        #expect(ShapeLayout.lengths(of: [segment(0), segment(0)], in: 42, spacing: 2) == [20, 20])
    }

    @Test func noSegments_giveNoLengths() {
        #expect(ShapeLayout.lengths(of: [], in: 100, spacing: 2).isEmpty)
    }

    // MARK: - Spacing

    @Test func spacing_isKept_whileEverySegmentStillGetsAPoint() {
        // 10 segments need 9 gaps of 2 and 10 points: 28.
        #expect(ShapeLayout.spacing(forCount: 10, in: 28, preferred: 2) == 2)
        #expect(ShapeLayout.spacing(forCount: 10, in: 27, preferred: 2) == 0)
        #expect(ShapeLayout.spacing(forCount: 1, in: 100, preferred: 2) == 0)
    }

    /// 20 rounds with a rest are 39 segments: more gaps than a day tile of 74 points holds.
    @Test func crowdedShape_dropsTheGaps_andStillFits() {
        let segments = (0..<39).map { _ in segment(60) }
        let length: CGFloat = 74

        let spacing = ShapeLayout.spacing(forCount: segments.count, in: length, preferred: 2)
        let lengths = ShapeLayout.lengths(of: segments, in: length, spacing: spacing)
        let drawn = lengths.reduce(0, +) + spacing * CGFloat(segments.count - 1)

        #expect(spacing == 0)
        #expect(abs(drawn - length) < 0.001)
    }

    // MARK: - Runs

    @Test func runs_joinALoopsSegments_withTheGapsBetweenThem() {
        let loop = UUID()
        let segments = [segment(60), segment(60, loop: loop), segment(60, loop: loop), segment(60)]

        let runs = ShapeLayout.runs(of: segments, lengths: [10, 20, 30, 40], spacing: 2)

        #expect(runs == [
            .init(isLoop: false, length: 10),
            .init(isLoop: true, length: 52),
            .init(isLoop: false, length: 40)
        ])
    }

    @Test func neighbouringLoops_andSingleSteps_stayApart() {
        let first = UUID(), second = UUID()
        let segments = [segment(60, loop: first), segment(60, loop: second), segment(60), segment(60)]

        let runs = ShapeLayout.runs(of: segments, lengths: [10, 10, 10, 10], spacing: 2)

        #expect(runs.map(\.isLoop) == [true, true, false, false])
        #expect(runs.map(\.length) == [10, 10, 10, 10])
    }
}
