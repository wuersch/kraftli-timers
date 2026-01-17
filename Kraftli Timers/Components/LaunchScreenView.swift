//
//  LaunchScreenView.swift
//  Kraftli Timers
//
//  Animated launch screen with spinning concentric arcs around the app icon.
//  Shows for 3 seconds on cold start, with arcs settling into place before fade-out.
//

import SwiftUI

struct LaunchScreenView: View {
    let onComplete: () -> Void

    // MARK: - Animation State

    // Arc rotations (in degrees)
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0

    // Arc scales (start small, expand)
    @State private var outerScale: CGFloat = 0.6
    @State private var innerScale: CGFloat = 0.5

    // Title opacity (fades in)
    @State private var titleOpacity: Double = 0

    // Overall screen opacity (fades out at end)
    @State private var screenOpacity: Double = 1

    // MARK: - Constants

    private let outerArcLength: CGFloat = 0.65  // 234° arc
    private let innerArcLength: CGFloat = 0.45  // 162° arc
    private let outerStrokeWidth: CGFloat = 4
    private let innerStrokeWidth: CGFloat = 3
    private let outerSize: CGFloat = 160
    private let innerSize: CGFloat = 110
    private let iconSize: CGFloat = 64

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon with spinning arcs
                ZStack {
                    // Outer arc (clockwise, faster)
                    Circle()
                        .trim(from: 0, to: outerArcLength)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: outerStrokeWidth, lineCap: .round)
                        )
                        .frame(width: outerSize, height: outerSize)
                        .rotationEffect(.degrees(outerRotation - 90))
                        .scaleEffect(outerScale)

                    // Inner arc (counter-clockwise, slower)
                    Circle()
                        .trim(from: 0, to: innerArcLength)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: innerStrokeWidth, lineCap: .round)
                        )
                        .frame(width: innerSize, height: innerSize)
                        .rotationEffect(.degrees(innerRotation - 90))
                        .scaleEffect(innerScale)

                    // Push-up icon in center
                    Image("pushup")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(.white)
                }
                .frame(width: outerSize, height: outerSize)

                // App title
                Text("Kraftli Timers")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
            }
        }
        .opacity(screenOpacity)
        .onAppear {
            startAnimationSequence()
        }
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Phase 1: Arcs expand and spin, overshooting slightly (0 - 2.5s)
        // Outer arc: 3 full rotations + overshoot, expands to full size
        withAnimation(.easeOut(duration: 2.5)) {
            outerRotation = 360 * 3 + 30  // Overshoot past 12 o'clock
            outerScale = 1.0
        }

        // Inner arc: 2 full rotations CCW + overshoot, expands to full size
        withAnimation(.easeOut(duration: 2.5)) {
            innerRotation = -360 * 2 - 25  // Overshoot past 12 o'clock (CCW)
            innerScale = 1.0
        }

        // Phase 2: Title fades in (1.2s - 2.0s)
        withAnimation(.easeIn(duration: 0.8).delay(1.2)) {
            titleOpacity = 1.0
        }

        // Phase 3: Settle back to exactly 12 o'clock (2.5s - 2.8s)
        // Like timer arcs that end at 12 o'clock when time elapses
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                outerRotation = 360 * 3  // Exactly 12 o'clock
                innerRotation = -360 * 2  // Exactly 12 o'clock
            }
        }

        // Phase 4: Fade out (2.7s - 3.0s)
        withAnimation(.easeIn(duration: 0.3).delay(2.7)) {
            screenOpacity = 0
        }

        // Phase 5: Complete - notify parent (3.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onComplete()
        }
    }
}

// MARK: - Preview

#Preview("Launch Screen Animation") {
    LaunchScreenView {
        print("Animation complete")
    }
}

#Preview("Launch Screen - Static End State") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 24) {
            ZStack {
                // Outer arc at 12 o'clock (final position)
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))  // 12 o'clock

                // Inner arc at 12 o'clock (final position)
                Circle()
                    .trim(from: 0, to: 0.45)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))  // 12 o'clock

                // Icon
                Image("pushup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.white)
            }

            Text("Kraftli Timers")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
