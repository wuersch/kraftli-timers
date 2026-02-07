//
//  AppSettings.swift
//  Kraftli Timers
//
//  User preferences stored in UserDefaults with Observable tracking.
//  Injected into the environment for global access.
//

import SwiftUI

/// User preferences for app behavior.
///
/// Uses `@Observable` for SwiftUI reactivity with manual UserDefaults persistence.
/// Injected via `.environment(settings)`.
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

    private enum Key: String {
        case audioEnabled
        case completionSoundStyle
        case confettiEnabled
        case launchScreenEnabled
        case smoothAnimationsEnabled
        case emomShowRepsInCenter
    }

    // MARK: - Audio Preferences

    /// Whether audio feedback is enabled.
    var audioEnabled: Bool {
        didSet { save(audioEnabled, for: .audioEnabled) }
    }

    /// The sound style played when a workout completes.
    var completionSoundStyle: CompletionSoundStyle {
        didSet { save(completionSoundStyle.rawValue, for: .completionSoundStyle) }
    }

    // MARK: - Visual Preferences

    /// Whether to show confetti animation when a workout completes.
    var confettiEnabled: Bool {
        didSet { save(confettiEnabled, for: .confettiEnabled) }
    }

    /// Whether to show the animated launch screen on app start.
    var launchScreenEnabled: Bool {
        didSet { save(launchScreenEnabled, for: .launchScreenEnabled) }
    }

    /// Whether to use 60 FPS display-synced updates for fluid timer animations.
    var smoothAnimationsEnabled: Bool {
        didSet { save(smoothAnimationsEnabled, for: .smoothAnimationsEnabled) }
    }

    /// Whether to show reps count in center of EMOM timer instead of interval countdown.
    var emomShowRepsInCenter: Bool {
        didSet { save(emomShowRepsInCenter, for: .emomShowRepsInCenter) }
    }

    // MARK: - Initialization

    init() {
        self.audioEnabled = Self.load(.audioEnabled, default: true)
        self.completionSoundStyle = Self.load(.completionSoundStyle, default: .cheering)
        self.confettiEnabled = Self.load(.confettiEnabled, default: true)
        self.launchScreenEnabled = Self.load(.launchScreenEnabled, default: true)
        self.smoothAnimationsEnabled = Self.load(.smoothAnimationsEnabled, default: true)
        self.emomShowRepsInCenter = Self.load(.emomShowRepsInCenter, default: false)
    }

    // MARK: - Persistence Helpers

    private func save(_ value: Any, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private static func load<T>(_ key: Key, default defaultValue: T) -> T {
        UserDefaults.standard.object(forKey: key.rawValue) as? T ?? defaultValue
    }

    private static func load(_ key: Key, default defaultValue: CompletionSoundStyle) -> CompletionSoundStyle {
        guard let raw = UserDefaults.standard.string(forKey: key.rawValue) else {
            return defaultValue
        }
        return CompletionSoundStyle(rawValue: raw) ?? defaultValue
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

        /// Creates the appropriate feedback provider for this sound style.
        func makeFeedbackProvider() -> any FeedbackProvider {
            switch self {
            case .cheering:
                return SystemSoundFeedback()
            case .neutral:
                return NeutralSoundFeedback()
            }
        }
    }
}
