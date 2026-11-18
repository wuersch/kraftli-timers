//
//  WeekPlanTests.swift
//  Kraftli TimersTests
//
//  The week plan and how it follows its sessions (UC-0014, ADR-0011).
//

import Foundation
import SwiftData
import Testing
@testable import Kraftli_Timers

@MainActor
struct WeekPlanTests {

    // MARK: - Plan record (no store needed)

    @Test func eachWeekday_holdsItsOwnSession() {
        let plan = WeekPlan()
        let ids = (1...7).map { _ in UUID() }

        for weekday in 1...7 {
            plan.setSessionId(ids[weekday - 1], on: weekday)
        }

        #expect((1...7).map { plan.sessionId(on: $0) } == ids)
    }

    @Test func assigning_replacesWhatWasPlanned_andNilMakesARestDay() {
        let plan = WeekPlan()
        let second = UUID()

        plan.setSessionId(UUID(), on: 3)
        plan.setSessionId(second, on: 3)
        #expect(plan.sessionId(on: 3) == second)

        plan.setSessionId(nil, on: 3)
        #expect(plan.sessionId(on: 3) == nil)
    }

    @Test func sameSession_canBePlannedOnSeveralDays_andIsFreedOnAllOfThem() {
        let plan = WeekPlan()
        let session = UUID()
        let other = UUID()
        plan.setSessionId(session, on: 2)
        plan.setSessionId(session, on: 5)
        plan.setSessionId(other, on: 7)

        #expect(plan.weekdays(of: session) == [2, 5])

        plan.free(session)

        #expect(plan.weekdays(of: session).isEmpty)
        #expect(plan.sessionId(on: 7) == other)
    }

    @Test func idWithoutASession_countsAsARestDay() {
        let plan = WeekPlan()
        let session = TrainingSession(name: "Legs")
        plan.setSessionId(session.id, on: 2)
        plan.setSessionId(UUID(), on: 3)   // deleted elsewhere

        #expect(plan.session(on: 2, among: [session]) === session)
        #expect(plan.session(on: 3, among: [session]) == nil)
        #expect(plan.session(on: 4, among: [session]) == nil)
    }

    @Test func ofSeveralPlans_theLowestIdIsUsed_whateverTheOrder() {
        let low = WeekPlan(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let high = WeekPlan(id: UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!)

        #expect(WeekPlan.current(among: [high, low]) === low)
        #expect(WeekPlan.current(among: [low, high]) === low)
        #expect(WeekPlan.current(among: []) == nil)
    }

    // MARK: - Session record

    @Test func session_keepsItsElementsThroughTheStoredDocument() {
        let step = SessionStep(kind: .amrap, exerciseId: nil, durationInterval: 240, targetReps: nil)
        let session = TrainingSession(name: "Upper Body", elements: [.step(step)])

        #expect(session.elementsData != nil)
        #expect(session.elements == [.step(step)])

        session.elements = []
        #expect(session.elements.isEmpty)
    }

    // MARK: - With a store

    @Test func firstAssignment_createsThePlan_laterOnesReuseIt() throws {
        // Keep the container: a context doesn't keep its container alive.
        let container = try makeInMemoryContainer(for: TrainingSession.self, WeekPlan.self)
        let context = container.mainContext
        let session = TrainingSession(name: "Legs")
        context.insert(session)

        WeekPlanning.plan(session, on: 2, plans: [], in: context)
        try context.save()
        var plans = try context.fetch(FetchDescriptor<WeekPlan>())
        #expect(plans.count == 1)

        WeekPlanning.plan(session, on: 5, plans: plans, in: context)
        try context.save()
        plans = try context.fetch(FetchDescriptor<WeekPlan>())
        #expect(plans.count == 1)
        #expect(plans[0].weekdays(of: session.id) == [2, 5])
    }

    @Test func clearingADay_withoutAPlan_createsNone() throws {
        // Keep the container: a context doesn't keep its container alive.
        let container = try makeInMemoryContainer(for: TrainingSession.self, WeekPlan.self)
        let context = container.mainContext

        WeekPlanning.plan(nil, on: 2, plans: [], in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<WeekPlan>()).isEmpty)
    }

    @Test func deletingASession_freesItsWeekdays() throws {
        // Keep the container: a context doesn't keep its container alive.
        let container = try makeInMemoryContainer(for: TrainingSession.self, WeekPlan.self)
        let context = container.mainContext
        let legs = TrainingSession(name: "Legs")
        let upper = TrainingSession(name: "Upper Body")
        context.insert(legs)
        context.insert(upper)
        WeekPlanning.plan(legs, on: 2, plans: [], in: context)
        try context.save()
        let plans = try context.fetch(FetchDescriptor<WeekPlan>())
        WeekPlanning.plan(upper, on: 3, plans: plans, in: context)

        WeekPlanning.delete(legs, plans: plans, in: context)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        #expect(sessions.map(\.name) == ["Upper Body"])
        #expect(plans[0].sessionId(on: 2) == nil)
        #expect(plans[0].sessionId(on: 3) == upper.id)
    }
}
