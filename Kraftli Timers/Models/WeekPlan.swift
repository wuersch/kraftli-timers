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

    /// The attribute of each weekday, in `Calendar`'s numbering: 1 = Sunday … 7 = Saturday.
    ///
    /// A key path names a property without reading it, so one list serves both reading
    /// and writing a day. The attributes stay seven separate ones because that is what
    /// the CloudKit record looks like (ADR-0011).
    private static var dayKeyPaths: [ReferenceWritableKeyPath<WeekPlan, UUID?>] {
        [\.sundayId, \.mondayId, \.tuesdayId, \.wednesdayId, \.thursdayId, \.fridayId, \.saturdayId]
    }

    private static func keyPath(of weekday: Int) -> ReferenceWritableKeyPath<WeekPlan, UUID?>? {
        let keyPaths = dayKeyPaths
        return keyPaths.indices.contains(weekday - 1) ? keyPaths[weekday - 1] : nil
    }

    /// The id planned on `weekday`; `nil` for a rest day and for a number that is no weekday.
    func sessionId(on weekday: Int) -> UUID? {
        Self.keyPath(of: weekday).flatMap { self[keyPath: $0] }
    }

    /// Plans a session on `weekday`, replacing what was there; `nil` makes it a rest day.
    func setSessionId(_ sessionId: UUID?, on weekday: Int) {
        guard let keyPath = Self.keyPath(of: weekday) else { return }
        self[keyPath: keyPath] = sessionId
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
