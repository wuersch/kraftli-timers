//
//  WatchMetricRow.swift
//  Kraftli Timers Watch App
//
//  A single numerical metric line for the Watch active-workout screen,
//  modeled on the Apple Workout app: a large monospaced value with a trailing
//  accessory — either a 1–2 line caption label (e.g. ACTIVE / KCAL) or a
//  vertically-centered SF Symbol (e.g. the heart for BPM). All rows share one
//  number size so the stack reads as a uniform column; color conveys each
//  metric's identity.
//

import SwiftUI

struct WatchMetricRow: View {
    /// The formatted value, e.g. "12:34", "3/20", "146".
    let value: String
    /// First (or only) caption line, e.g. "TOTAL", "ACTIVE".
    var labelTop: String? = nil
    /// Optional second caption line, e.g. "KCAL".
    var labelBottom: String? = nil
    /// Trailing SF Symbol shown *instead* of a text label, e.g. "heart.fill".
    var symbol: String? = nil
    var valueColor: Color = .primary
    var labelColor: Color = .secondary
    var symbolColor: Color = .secondary
    /// Uniform across all rows — the single knob for tuning the column size.
    var valueSize: CGFloat = 26
    var valueWeight: Font.Weight = .semibold

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(value)
                .font(.system(size: valueSize, weight: valueWeight, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(valueColor)

            trailingAccessory
        }
    }

    /// A centered symbol takes priority; otherwise the 1–2 line caption stack.
    /// Both sit vertically centered on the number, so the caption's combined
    /// height tracks the number height (the Apple "ACTIVE / KCAL" layout).
    @ViewBuilder
    private var trailingAccessory: some View {
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: valueSize * 0.5, weight: .semibold))
                .foregroundStyle(symbolColor)
        } else if labelTop != nil || labelBottom != nil {
            VStack(alignment: .leading, spacing: 0) {
                if let labelTop {
                    Text(labelTop)
                }
                if let labelBottom {
                    Text(labelBottom)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(labelColor)
            .lineLimit(1)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 6) {
        WatchMetricRow(value: "18:46", labelTop: "TOTAL", valueColor: .blue)
        WatchMetricRow(value: "00:10", labelTop: "INTERVAL", valueColor: .blue)
        WatchMetricRow(value: "6/100", labelTop: "REPS")
        WatchMetricRow(value: "61", symbol: "heart.fill", symbolColor: .red)
        WatchMetricRow(value: "0", labelTop: "ACTIVE", labelBottom: "KCAL", labelColor: .orange)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
