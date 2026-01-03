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
}
