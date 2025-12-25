//
//  RepsPill.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 25.12.2025.
//

import SwiftUI

struct RepsPill: View {
    let text: AttributedString
    let accentColor: Color

    var body: some View {
        Text(text)
            .font(.subheadline)
            .monospacedDigit()
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.25))
                    .stroke(
                        accentColor,
                        style: StrokeStyle(
                            lineWidth: 1,
                            lineCap: .round
                        )
                    )
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        RepsPill(
            text: AttributedString("12/20 REPS"),
            accentColor: .blue
        )

        RepsPill(
            text: AttributedString("DONE ⸱ Hold to close"),
            accentColor: .green
        )
    }
    .padding()
}
