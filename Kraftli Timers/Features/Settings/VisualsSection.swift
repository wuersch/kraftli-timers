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

            VStack(spacing: 0) {
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
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 0) {
                // Launch Screen Toggle
                Toggle(isOn: $settings.launchScreenEnabled) {
                    Label("Launch Animation", systemImage: "wand.and.stars")
                }
                .padding()

                Divider()

                Text("Shows an animated splash screen when the app starts.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
