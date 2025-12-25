//
//  ProgressRing.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 25.12.2025.
//

import SwiftUI

struct ProgressRing: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let progress: Double
    let color: Color
    let backgroundColor: Color
    let rotationDegrees: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotationDegrees))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressRing(
            size: 200,
            lineWidth: 20,
            progress: 0.75,
            color: .blue,
            backgroundColor: .gray.opacity(0.2),
            rotationDegrees: -90
        )

        ProgressRing(
            size: 100,
            lineWidth: 10,
            progress: 0.3,
            color: .orange,
            backgroundColor: .gray.opacity(0.2),
            rotationDegrees: -90
        )
    }
}
