//
//  WeekPlanning.swift
//  Kraftli Timers
//
//  Changes to the week plan and to the sessions it refers to (UC-0013, UC-0014).
//

import Foundation
import SwiftData

@MainActor
enum WeekPlanning {
    /// Plans `session` on `weekday`; `nil` makes it a rest day. The first assignment
    /// creates the plan record.
    static func plan(_ session: TrainingSession?, on weekday: Int, plans: [WeekPlan], in context: ModelContext) {
        if let plan = WeekPlan.current(among: plans) {
            plan.setSessionId(session?.id, on: weekday)
        } else if let session {
            let plan = WeekPlan()
            plan.setSessionId(session.id, on: weekday)
            context.insert(plan)
        }
    }

    /// Deletes `session` and makes the weekdays it was planned on rest days.
    static func delete(_ session: TrainingSession, plans: [WeekPlan], in context: ModelContext) {
        for plan in plans {
            plan.free(session.id)
        }
        context.delete(session)
    }
}
