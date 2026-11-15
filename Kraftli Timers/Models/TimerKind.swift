//
//  TimerKind.swift
//  Kraftli Timers
//
//  Timer type enumeration.
//

import Foundation
import HealthKit

enum TimerKind: String, Codable, CaseIterable {
    case emom  = "EMOM"
    case amrap = "AMRAP"
    case forTime = "For Time"

    /// False for For Time, which counts up until declared done; the other kinds are
    /// time-boxed (ADR-0010).
    var hasFixedDuration: Bool {
        switch self {
        case .emom, .amrap: true
        case .forTime: false
        }
    }

    /// Maps timer kind to the most appropriate HealthKit activity type.
    /// All kinds are forms of high-intensity interval training.
    var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .emom, .amrap, .forTime:
            return .highIntensityIntervalTraining
        }
    }
}
