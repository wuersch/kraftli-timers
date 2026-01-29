//
//  VisualsSection.swift
//  Kraftli Timers
//
//  Settings section for visual preferences like confetti.
//

import SwiftUI

struct VisualsSection: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 12) {
            Text("Visuals")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 0) {
                // Launch Screen Toggle
                Toggle(isOn: $settings.launchScreenEnabled) {
                    Label("Launch Animation", systemImage: "movieclapper")
                }
                .padding()

                Divider()

                Text("Shows an animated splash screen when the app starts.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding()
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 0) {
                // Confetti Toggle
                Toggle(isOn: $settings.confettiEnabled) {
                    Label("Confetti", systemImage: "party.popper")
                }
                .padding()

                Divider()

                Text("Shows celebratory confetti when you complete a workout.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding()
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 0) {
                // Smooth Animations Toggle
                Toggle(isOn: $settings.smoothAnimationsEnabled) {
                    Label("Smooth Animations", systemImage: "waveform.path")
                }
                .padding()

                Divider()

                Text("Uses 60 FPS display-synced updates for fluid timer animations. Disable for improved battery life during long workouts.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding()
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 0) {
                // EMOM Reps in Center Toggle
                Toggle(isOn: $settings.emomShowRepsInCenter) {
                    Label("Show Reps in Center", systemImage: "number")
                }
                .padding()

                Divider()

                Text("Displays reps count prominently in the EMOM timer instead of interval countdown.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding()
            }
            .cardStyle()
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VisualsSection()
            .padding()
    }
    .environment(AppSettings())
}
