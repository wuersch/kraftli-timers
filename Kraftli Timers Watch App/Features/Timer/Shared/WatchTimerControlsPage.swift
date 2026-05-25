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

struct WatchTimerControlsPage: View {
    let isRunning: Bool
    let isCompleted: Bool
    let onStop: () -> Void
    let onPlayPause: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Stop = red; Play = green, Pause = yellow (gray once completed).
            controlButton(systemName: "xmark", color: .red, action: onStop)
            controlButton(
                systemName: isRunning ? "pause.fill" : "play.fill",
                color: isCompleted ? .gray : (isRunning ? .yellow : .green),
                action: onPlayPause
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlButton(
        systemName: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.25))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
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
