//
//  Logger+App.swift
//  Kraftli Timers
//
//  App-specific loggers for structured logging.
//  Logs are visible in Xcode console and Console.app.
//

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kraftli.timers"

    /// Logs related to audio and sound playback
    static let audio = Logger(subsystem: subsystem, category: "audio")

    /// Logs related to data loading and persistence
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Logs related to Watch connectivity and sync
    static let watchConnectivity = Logger(subsystem: subsystem, category: "watchConnectivity")

    /// Logs related to workout logging and persistence
    static let workoutLogging = Logger(subsystem: subsystem, category: "workoutLogging")

    /// Logs related to HealthKit authorization and workout saving
    static let healthKit = Logger(subsystem: subsystem, category: "healthKit")

    /// Logs related to workout session coordination (multi-device)
    static let workoutSession = Logger(subsystem: subsystem, category: "workoutSession")
}
