//
//  TrainingView.swift
//  Kraftli Timers
//
//  The Training tab: the week plan and the sessions (UC-0013, UC-0014).
//

import SwiftData
import SwiftUI

struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedSessions: [TrainingSession]
    @Query private var plans: [WeekPlan]

    @State private var selectedWeekday = WeekLayout.weekday()
    @State private var sheet: Sheet?
    @State private var sessionToDelete: TrainingSession?

    private enum Sheet: Identifiable {
        case new
        case edit(TrainingSession)
        case copy(of: TrainingSession)
        case plan(weekday: Int)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let session): "edit-\(session.id.uuidString)"
            case .copy(let session): "copy-\(session.id.uuidString)"
            case .plan(let weekday): "plan-\(weekday)"
            }
        }
    }

    /// Alphabetical. Two sessions can have the same name after a sync (ADR-0011); the id
    /// then keeps their order the same on every device.
    private var sessions: [TrainingSession] {
        storedSessions.sorted { first, second in
            switch first.name.localizedCaseInsensitiveCompare(second.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: first.id.uuidString < second.id.uuidString
            }
        }
    }

    private var plan: WeekPlan? {
        WeekPlan.current(among: plans)
    }

    private func plannedSession(on weekday: Int) -> TrainingSession? {
        plan?.session(on: weekday, among: storedSessions)
    }

    // MARK: - Body

    var body: some View {
        let today = WeekLayout.weekday()
        let selectedSession = plannedSession(on: selectedWeekday)

        List {
            if !sessions.isEmpty {
                WeekStripView(
                    weekdays: WeekLayout.orderedWeekdays(),
                    today: today,
                    selectedWeekday: $selectedWeekday,
                    session: plannedSession(on:)
                )
                .cardListRow()

                Group {
                    if let selectedSession {
                        SelectedDayCard(
                            title: dayTitle(selectedWeekday, today: today),
                            session: selectedSession,
                            onChange: { sheet = .plan(weekday: selectedWeekday) }
                        )
                        // Takes the session off this day; the session itself stays. Not
                        // destructive, so no red and no confirmation: one tap plans it again.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Remove", systemImage: "calendar.badge.minus") {
                                withAnimation {
                                    WeekPlanning.plan(nil, on: selectedWeekday, plans: plans, in: modelContext)
                                }
                            }
                        }
                    } else {
                        restDay(title: dayTitle(selectedWeekday, today: today))
                    }
                }
                .cardListRow()

                Text("Sessions")
                    .font(.title3.weight(.bold))
                    .padding(.top, 8)
                    .cardListRow()

                ForEach(sessions) { session in
                    sessionRow(session, plannableOn: selectedSession == nil ? selectedWeekday : nil)
                        .cardListRow()
                }
            }
        }
        .cardListStyle(isEmpty: sessions.isEmpty)
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions", systemImage: "calendar")
                } description: {
                    Text("Compose a session first, then plan it on your training days.")
                } actions: {
                    Button("New Session") { sheet = .new }
                }
            }
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheet = .new
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New session")
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .new:
                SessionEditorView()
            case .edit(let session):
                SessionEditorView(session: session)
            case .copy(let session):
                SessionEditorView(
                    startingWith: SessionDraft(copyOf: session, existingNames: storedSessions.map(\.name))
                )
            case .plan(let weekday):
                DayPlanSheet(
                    weekday: weekday,
                    sessions: sessions,
                    plannedSessionID: plannedSession(on: weekday)?.id
                ) { session in
                    WeekPlanning.plan(session, on: weekday, plans: plans, in: modelContext)
                }
            }
        }
        .alert(
            "Delete \u{201C}\(sessionToDelete?.name ?? "")\u{201D}?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            presenting: sessionToDelete
        ) { session in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                WeekPlanning.delete(session, plans: plans, in: modelContext)
            }
        } message: { _ in
            Text("It is also removed from your week. This action cannot be undone.")
        }
    }

    // MARK: - Rows

    private func restDay(title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text("Rest day")
                .font(.title.weight(.bold))
                .foregroundStyle(.secondary)
            Text("Tap + on a session to train on \(WeekLayout.name(of: selectedWeekday))s.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    /// A session in the list. While a rest day is selected, the row also offers to plan
    /// the session on that day.
    private func sessionRow(_ session: TrainingSession, plannableOn weekday: Int?) -> some View {
        HStack(spacing: 14) {
            SessionCardContent(session: session, detail: plannedDaysText(of: session))

            if let weekday {
                Button {
                    withAnimation {
                        WeekPlanning.plan(session, on: weekday, plans: plans, in: modelContext)
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Plan \(session.name) on \(WeekLayout.name(of: weekday))")
            }
        }
        .padding(14)
        .cardStyle(padded: false)
        .contentShape(Rectangle())
        .onTapGesture { sheet = .edit(session) }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the session")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                sessionToDelete = session
            }
        }
        .contextMenu {
            Button("Duplicate", systemImage: "plus.square.on.square") {
                sheet = .copy(of: session)
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                sessionToDelete = session
            }
        }
    }

    // MARK: - Text

    /// "TODAY · TUESDAY" or "WEDNESDAY"
    private func dayTitle(_ weekday: Int, today: Int) -> String {
        let name = WeekLayout.name(of: weekday).uppercased()
        return weekday == today ? "TODAY" + UISeparator.dot + name : name
    }

    /// "Mon, Thu": the days the session is planned on, in the week's order.
    private func plannedDaysText(of session: TrainingSession) -> String? {
        guard let plan else { return nil }
        let planned = plan.weekdays(of: session.id)
        let days = WeekLayout.orderedWeekdays().filter(planned.contains).map { WeekLayout.shortName(of: $0) }
        return days.isEmpty ? nil : days.joined(separator: ", ")
    }
}

#Preview("Empty") {
    NavigationStack {
        TrainingView()
    }
    .modelContainer(for: [TrainingSession.self, WeekPlan.self, TimerPreset.self], inMemory: true)
}
