//
//  DigitalCrownStepperView.swift
//  Kraftli Timers Watch App
//
//  Reusable component for numeric input via Digital Crown.
//

import SwiftUI

/// A watchOS-optimized numeric input control using Digital Crown.
///
/// ## Usage
/// ```swift
/// @State private var duration: Double = 20
///
/// DigitalCrownStepperView(
///     label: "Duration",
///     value: $duration,
///     unit: "min",
///     range: 1...60
/// )
/// ```
///
/// ## Features
/// - Digital Crown rotation for value adjustment
/// - Visual feedback with focus highlight
/// - Haptic feedback on value changes
/// - Constrained to specified range
struct DigitalCrownStepperView: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>
    let step: Double

    @State private var isFocused = false
    @FocusState private var crownFocused: Bool

    init(
        label: String,
        value: Binding<Double>,
        unit: String,
        range: ClosedRange<Double>,
        step: Double = 1
    ) {
        self.label = label
        self._value = value
        self.unit = unit
        self.range = range
        self.step = step
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(Int(value))")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(isFocused ? .green : .primary)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "digitalcrown.horizontal.arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(isFocused ? Color.green : Color.gray.opacity(0.5))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
            )
            .focusable()
            .focused($crownFocused)
            .digitalCrownRotation(
                $value,
                from: range.lowerBound,
                through: range.upperBound,
                by: step,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            crownFocused = true
        }
        .onChange(of: crownFocused) { _, focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = focused
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var duration: Double = 20
        @State private var reps: Double = 100

        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    DigitalCrownStepperView(
                        label: "Duration",
                        value: $duration,
                        unit: "min",
                        range: 1...60
                    )

                    DigitalCrownStepperView(
                        label: "Total Reps",
                        value: $reps,
                        unit: "reps",
                        range: 1...400
                    )
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
