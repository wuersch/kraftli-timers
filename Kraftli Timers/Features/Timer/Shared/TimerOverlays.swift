//
//  TimerOverlays.swift
//  Kraftli Timers
//
//  Overlay components shown on top of timer views (handle, hints, confetti).
//

import SwiftUI

/// Overlay components for timer views including drag handle, swipe hint, and confetti.
///
/// Groups the overlay elements that appear on top of the timer content.
/// Hidden during countdown to avoid visual clutter.
///
/// ## Usage
/// ```swift
/// TimerOverlays(
///     isCountingDown: countdown.isCountingDown,
///     isHandleActive: isHandleActive,
///     dragOffset: dragOffset,
///     showHint: session.showHint,
///     showConfetti: session.showConfetti,
///     confettiEnabled: confettiEnabled,
///     labelFont: sizes.labelFont
/// )
/// ```
struct TimerOverlays: View {
    let isCountingDown: Bool
    let isHandleActive: Bool
    let dragOffset: CGFloat
    let showHint: Bool
    let showConfetti: Bool
    let confettiEnabled: Bool
    let labelFont: CGFloat

    var body: some View {
        // Hide handle during countdown
        if !isCountingDown {
            DragHandleView(isActive: isHandleActive, dragOffset: dragOffset)
        }

        // Hide swipe hint during countdown
        if !isCountingDown {
            SwipeHintOverlay(isVisible: showHint, fontSize: labelFont)
        }

        if confettiEnabled && showConfetti {
            ConfettiView()
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#Preview("Timer Overlays") {
    ZStack {
        Color.black.ignoresSafeArea()

        TimerOverlays(
            isCountingDown: false,
            isHandleActive: false,
            dragOffset: 0,
            showHint: true,
            showConfetti: false,
            confettiEnabled: true,
            labelFont: 15
        )
    }
}
