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

            SettingsToggleCard(
                title: "Launch Animation",
                icon: "movieclapper",
                description: "Shows an animated splash screen when the app starts.",
                isOn: $settings.launchScreenEnabled
            )

            SettingsToggleCard(
                title: "Confetti",
                icon: "party.popper",
                description: "Shows celebratory confetti when you complete a workout.",
                isOn: $settings.confettiEnabled
            )

            SettingsToggleCard(
                title: "Smooth Animations",
                icon: "waveform.path",
                description: "Uses 60 FPS display-synced updates for fluid timer animations. Disable for improved battery life during long workouts.",
                isOn: $settings.smoothAnimationsEnabled
            )

            SettingsToggleCard(
                title: "Show Reps in Center",
                icon: "number",
                description: "Displays reps count prominently in the EMOM timer instead of interval countdown.",
                isOn: $settings.emomShowRepsInCenter
            )
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
