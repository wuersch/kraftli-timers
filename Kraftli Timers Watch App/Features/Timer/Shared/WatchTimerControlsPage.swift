//
//  WatchTimerControlsPage.swift
//  Kraftli Timers Watch App
//
//  Controls page (the second TabView page) for the Watch active-workout
//  screen: Stop and Play/Pause. These were previously overlaid at the bottom
//  of the ring view; with the Apple-style numerical layout they live on their
//  own swipe page so the metrics page stays uncluttered. Shared by EMOM/AMRAP.
//

import SwiftUI

/// The two swipe pages of the Watch active-workout screen. Controls sit to the
/// *left* of the metrics page (Apple Workout parity); the `TabView` selection
/// defaults to `.metrics`, so metrics is shown on launch and a swipe-right
/// reveals the controls.
enum WorkoutPage {
    case controls
    case metrics
}

struct WatchTimerControlsPage: View {
    let isRunning: Bool
    let isCompleted: Bool
    let onStop: () -> Void
    let onPlayPause: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Apple Workout parity: End (red ✕) and a Pause/Resume button, each
            // with a text label beneath. With auto-start the right button is
            // only ever Pause (running) or Resume (paused, arrow.clockwise), so
            // it stays yellow (gray once completed).
            controlButton(systemName: "xmark", color: .red, label: "End", action: onStop)
            controlButton(
                systemName: isRunning ? "pause.fill" : "arrow.clockwise",
                color: isCompleted ? .gray : .yellow,
                label: isRunning ? "Pause" : "Resume",
                action: onPlayPause
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlButton(
        systemName: String,
        color: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.25))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchTimerControlsPage(
        isRunning: true,
        isCompleted: false,
        onStop: {},
        onPlayPause: {}
    )
}
