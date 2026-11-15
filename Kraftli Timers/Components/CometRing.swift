//
//  CometRing.swift
//  Kraftli Timers
//
//  A ring with a "comet": a solid round head and a tail that fades out behind it.
//

import SwiftUI

/// A gray track with a comet travelling around it, for open-ended (For Time) workouts.
///
/// The comet is built from two layers:
/// - **Tail:** a trimmed `Circle` stroked with an `AngularGradient` that runs from transparent
///   to `color` over the trimmed range. Both the trim and the gradient start at 3 o'clock and
///   run clockwise, so the gradient lines up with the arc before the whole layer is rotated.
/// - **Head:** a filled dot. It is offset to the top of the ring and then rotated: an
///   offset doesn't move a view's layout frame, so `rotationEffect` still turns it around
///   the ring's center.
///
/// The tail uses butt caps, since a round cap would pick up the wrong end of the gradient.
struct CometRing: View {
    let size: CGFloat
    let lineWidth: CGFloat
    /// Where the head is, measured clockwise from 12 o'clock.
    let headAngle: Angle
    /// Length of the tail as a fraction of the ring.
    var tailLength: Double = 0.3
    let color: Color
    var trackColor: Color = Color.gray.opacity(0.2)

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: tailLength)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0), color],
                        center: .center,
                        startAngle: .zero,
                        endAngle: .degrees(tailLength * 360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                // The trim starts at 3 o'clock: turn it so its end sits at the head.
                .rotationEffect(headAngle - .degrees(90 + tailLength * 360))

            Circle()
                .fill(color)
                .frame(width: lineWidth, height: lineWidth)
                .offset(y: -size / 2)
                .rotationEffect(headAngle)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 40) {
        CometRing(size: 200, lineWidth: 20, headAngle: .degrees(186), color: .orange)
        CometRing(size: 100, lineWidth: 10, headAngle: .zero, color: .orange)
    }
}
