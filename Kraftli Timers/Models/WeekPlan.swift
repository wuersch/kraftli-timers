//
//  WeekPlan.swift
//  Kraftli Timers
//
//  SwiftData model for the training week (UC-0014).
//

import Foundation
import SwiftData

/// Which session is planned on which weekday. The plan has no dates: it repeats
/// every week.
///
/// One record with one optional session id per weekday, so a weekday can't hold two
/// sessions. Sessions are referenced by id, not by a relationship; an id that no
/// session has counts as a rest day (ADR-0011).
@Model
final class WeekPlan {
    var id: UUID = UUID()
    var sundayId: UUID?
    var mondayId: UUID?
    var tuesdayId: UUID?
    var wednesdayId: UUID?
    var thursdayId: UUID?
    var fridayId: UUID?
    var saturdayId: UUID?

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// The id planned on `weekday`, numbered like `Calendar`: 1 = Sunday … 7 = Saturday.
    func sessionId(on weekday: Int) -> UUID? {
        switch weekday {
        case 1: sundayId
        case 2: mondayId
        case 3: tuesdayId
        case 4: wednesdayId
        case 5: thursdayId
        case 6: fridayId
        case 7: saturdayId
        default: nil
        }
    }

    /// Plans a session on `weekday`, replacing what was there; `nil` makes it a rest day.
    func setSessionId(_ sessionId: UUID?, on weekday: Int) {
        switch weekday {
        case 1: sundayId = sessionId
        case 2: mondayId = sessionId
        case 3: tuesdayId = sessionId
        case 4: wednesdayId = sessionId
        case 5: thursdayId = sessionId
        case 6: fridayId = sessionId
        case 7: saturdayId = sessionId
        default: break
        }
    }

    /// The weekdays `sessionId` is planned on.
    func weekdays(of sessionId: UUID) -> [Int] {
        (1...7).filter { self.sessionId(on: $0) == sessionId }
    }

    /// Makes every weekday `sessionId` is planned on a rest day.
    func free(_ sessionId: UUID) {
        for weekday in weekdays(of: sessionId) {
            setSessionId(nil, on: weekday)
        }
    }

    /// The session planned on `weekday`; `nil` for a rest day, and for an id that no
    /// session has (the session was deleted, perhaps on another device).
    func session(on weekday: Int, among sessions: [TrainingSession]) -> TrainingSession? {
        guard let sessionId = sessionId(on: weekday) else { return nil }
        return sessions.first { $0.id == sessionId }
    }

    /// The plan to use. There should be one, but two devices can each create one before
    /// they sync; then the lowest id wins on every device, and none is deleted.
    static func current(among plans: [WeekPlan]) -> WeekPlan? {
        plans.min { $0.id.uuidString < $1.id.uuidString }
    }
}
