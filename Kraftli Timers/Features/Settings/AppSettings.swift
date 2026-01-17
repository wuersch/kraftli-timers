//
//  AppSettings.swift
//  Kraftli Timers
//
//  User preferences stored in UserDefaults via @AppStorage.
//  Injected into the environment for global access.
//

import SwiftUI

/// User preferences for app behavior.
///
/// Uses `@Observable` for SwiftUI reactivity and `@AppStorage` for
/// automatic UserDefaults persistence. Injected via `.environment(settings)`.
///
/// ## Usage
/// ```swift
/// // In App:
/// @State private var settings = AppSettings()
/// ContentView().environment(settings)
///
/// // In views:
/// @Environment(AppSettings.self) private var settings
/// Toggle(isOn: $settings.confettiEnabled) { ... }
/// ```
@Observable
final class AppSettings {
    // MARK: - Keys

    private enum Keys {
        static let audioEnabled = "audioEnabled"
        static let completionSoundStyle = "completionSoundStyle"
        static let confettiEnabled = "confettiEnabled"
        static let launchScreenEnabled = "launchScreenEnabled"
    }

    // MARK: - Audio Preferences

    /// Whether audio feedback is enabled.
    var audioEnabled: Bool {
        didSet { UserDefaults.standard.set(audioEnabled, forKey: Keys.audioEnabled) }
    }

    /// The sound style played when a workout completes.
    var completionSoundStyle: CompletionSoundStyle {
        didSet { UserDefaults.standard.set(completionSoundStyle.rawValue, forKey: Keys.completionSoundStyle) }
    }

    // MARK: - Visual Preferences

    /// Whether to show confetti animation when a workout completes.
    var confettiEnabled: Bool {
        didSet { UserDefaults.standard.set(confettiEnabled, forKey: Keys.confettiEnabled) }
    }

    /// Whether to show the animated launch screen on app start.
    var launchScreenEnabled: Bool {
        didSet { UserDefaults.standard.set(launchScreenEnabled, forKey: Keys.launchScreenEnabled) }
    }

    // MARK: - Initialization

    init() {
        let defaults = UserDefaults.standard

        // Audio enabled defaults to true
        self.audioEnabled = defaults.object(forKey: Keys.audioEnabled) as? Bool ?? true

        // Completion sound style defaults to cheering
        let styleRaw = defaults.string(forKey: Keys.completionSoundStyle) ?? CompletionSoundStyle.cheering.rawValue
        self.completionSoundStyle = CompletionSoundStyle(rawValue: styleRaw) ?? .cheering

        // Confetti defaults to true
        self.confettiEnabled = defaults.object(forKey: Keys.confettiEnabled) as? Bool ?? true

        // Launch screen defaults to true
        self.launchScreenEnabled = defaults.object(forKey: Keys.launchScreenEnabled) as? Bool ?? true
    }

    // MARK: - Types

    /// Available completion sound styles.
    enum CompletionSoundStyle: String, CaseIterable, Identifiable {
        case cheering = "Cheering"
        case neutral = "Neutral"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .cheering:
                return "Crowd cheering sound"
            case .neutral:
                return "Simple beep sounds"
            }
        }

        /// Creates the appropriate audio feedback provider for this sound style.
        func makeAudioProvider() -> any AudioFeedbackProvider {
            switch self {
            case .cheering:
                return SystemSoundFeedback()
            case .neutral:
                return NeutralSoundFeedback()
            }
        }
    }
}
