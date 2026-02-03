//
//  Logger+App.swift
//  Kraftli Timers Watch App
//
//  App-specific loggers for structured logging.
//  Duplicated in Watch App target since extensions can't be shared across targets.
//

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kraftli.timers.watchkitapp"

    /// Logs related to Watch connectivity and sync
    static let watchConnectivity = Logger(subsystem: subsystem, category: "watchConnectivity")

    /// Logs related to workout logging and persistence
    static let workoutLogging = Logger(subsystem: subsystem, category: "workoutLogging")

    /// Logs related to timer sync between iPhone and Watch
    static let timerSync = Logger(subsystem: subsystem, category: "timerSync")

    /// Logs related to data loading
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Logs related to HealthKit authorization and workout saving
    static let healthKit = Logger(subsystem: subsystem, category: "healthKit")

    /// Logs related to workout session coordination (multi-device)
    static let workoutSession = Logger(subsystem: subsystem, category: "workoutSession")
}
