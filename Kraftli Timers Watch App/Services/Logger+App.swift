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
}
