//
//  TimeIntervalFormatTests.swift
//  Kraftli TimersTests
//

import Foundation
import Testing
@testable import Kraftli_Timers

struct TimeIntervalFormatTests {

    // MARK: - Interval Description Tests

    @Test func intervalDescription_formatsSecondsOnly() {
        let interval: TimeInterval = 30
        #expect(interval.intervalDescription() == "30 sec per interval")
        #expect(interval.intervalDescription(compact: true) == "30s interval")
    }

    @Test func intervalDescription_formatsMinutesOnly() {
        let interval: TimeInterval = 60
        #expect(interval.intervalDescription() == "1 min per interval")
        #expect(interval.intervalDescription(compact: true) == "1m interval")
    }

    @Test func intervalDescription_formatsMinutesAndSeconds() {
        let interval: TimeInterval = 90 // 1 min 30 sec
        #expect(interval.intervalDescription() == "1 min 30 sec per interval")
        #expect(interval.intervalDescription(compact: true) == "1m 30s interval")
    }

    @Test func intervalDescription_handlesMultipleMinutes() {
        let interval: TimeInterval = 150 // 2 min 30 sec
        #expect(interval.intervalDescription() == "2 min 30 sec per interval")
        #expect(interval.intervalDescription(compact: true) == "2m 30s interval")
    }

    @Test func intervalDescription_handlesZero() {
        let interval: TimeInterval = 0
        #expect(interval.intervalDescription() == "0 sec per interval")
        #expect(interval.intervalDescription(compact: true) == "0s interval")
    }
}
