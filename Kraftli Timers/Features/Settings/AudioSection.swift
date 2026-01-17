//
//  AudioSection.swift
//  Kraftli Timers
//
//  Settings section for audio preferences.
//

import SwiftUI

struct AudioSection: View {
    @Environment(AppSettings.self) private var settings

    private var cheeringBinding: Binding<Bool> {
        Binding(
            get: { settings.completionSoundStyle == .cheering },
            set: { settings.completionSoundStyle = $0 ? .cheering : .neutral }
        )
    }

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 12) {
            Text("Audio")
                .font(.headline)

            VStack(spacing: 0) {
                // Sound Toggle
                Toggle(isOn: $settings.audioEnabled) {
                    Label("Sound", systemImage: "speaker.wave.2")
                }
                .padding()

                // Cheer Toggle (only shown when audio is enabled)
                if settings.audioEnabled {
                    Divider()

                    Toggle(isOn: cheeringBinding) {
                        Label("Cheer on Completion", systemImage: "hands.clap")
                    }
                    .padding()

                    Divider()

                    Text("When enabled, plays a crowd cheering sound when you complete a workout. Otherwise plays simple beeps.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding()
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Preview

#Preview("Audio Enabled") {
    ScrollView {
        AudioSection()
            .padding()
    }
    .environment(AppSettings())
}

#Preview("Audio Disabled") {
    ScrollView {
        AudioSection()
            .padding()
    }
    .environment({
        let settings = AppSettings()
        settings.audioEnabled = false
        return settings
    }())
}
