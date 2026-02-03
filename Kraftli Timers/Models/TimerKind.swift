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

    /// Maps timer kind to the most appropriate HealthKit activity type.
    /// Both EMOM and AMRAP are forms of high-intensity interval training.
    var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .emom, .amrap:
            return .highIntensityIntervalTraining
        }
    }
}
