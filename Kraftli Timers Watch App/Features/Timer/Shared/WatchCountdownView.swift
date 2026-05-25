//
//  WatchCountdownView.swift
//  Kraftli Timers Watch App
//
//  Full-screen pre-workout countdown shown before the metric display appears.
//  Mirrors the prior ring-center countdown: a large "3 / 2 / 1 / GO" with a
//  "Get ready" caption beneath. Shared by the EMOM and AMRAP timer views.
//

import SwiftUI

struct WatchCountdownView: View {
    let countdown: WatchCountdownCoordinator

    var body: some View {
        VStack(spacing: 8) {
            Text(displayText)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .id(countdown.countdownValue)

            Text("Get ready")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 3/2/1 → the number, 0 → "GO", nil → empty.
    private var displayText: String {
        countdown.countdownValue.map { $0 > 0 ? "\($0)" : "GO" } ?? ""
    }
}
