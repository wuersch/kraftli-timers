//
//  SettingsToggleCard.swift
//  Kraftli Timers
//
//  Reusable toggle card for Settings with icon, label, and description.
//

import SwiftUI

/// A card-styled toggle with icon, label, and description text.
///
/// Used in Settings to create consistent toggle controls with explanatory text.
/// Combines a Toggle with an icon label, divider, and description.
///
/// ## Usage
/// ```swift
/// @Bindable var settings = settings
/// SettingsToggleCard(
///     title: "Confetti",
///     icon: "party.popper",
///     description: "Shows celebratory confetti when you complete a workout.",
///     isOn: $settings.confettiEnabled
/// )
/// ```
struct SettingsToggleCard: View {
    let title: String
    let icon: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $isOn) {
                Label(title, systemImage: icon)
            }
            .padding()

            Divider()

            Text(description)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding()
        }
        .cardStyle()
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            SettingsToggleCard(
                title: "Confetti",
                icon: "party.popper",
                description: "Shows celebratory confetti when you complete a workout.",
                isOn: .constant(true)
            )

            SettingsToggleCard(
                title: "Smooth Animations",
                icon: "waveform.path",
                description: "Uses 60 FPS display-synced updates for fluid timer animations.",
                isOn: .constant(false)
            )
        }
        .padding()
    }
}
