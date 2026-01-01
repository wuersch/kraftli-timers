//
//  SwipeHintOverlay.swift
//  Kraftli Timers
//
//  Extracted from timer views for reuse.
//

import SwiftUI

/// A hint overlay that appears at the bottom of dismissible views.
/// Shows "Swipe down to close" text with a fade transition.
struct SwipeHintOverlay: View {
    /// Whether the hint is currently visible
    let isVisible: Bool
    /// Font size for the hint text (typically from responsive TimerSizes)
    let fontSize: CGFloat

    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                Text("Swipe down to close")
                    .font(.system(size: fontSize))
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

#Preview("Visible") {
    ZStack {
        Color.black.ignoresSafeArea()
        SwipeHintOverlay(isVisible: true, fontSize: 15)
    }
}

#Preview("Hidden") {
    ZStack {
        Color.black.ignoresSafeArea()
        SwipeHintOverlay(isVisible: false, fontSize: 15)
    }
}
