//
//  SessionEditorView.swift
//  Kraftli Timers
//
//  The block editor for a training session (UC-0013).
//

import SwiftData
import SwiftUI

/// Creates or changes a session: its name and its blocks, stacked in running order.
///
/// The editor works on a `SessionDraft` and stores nothing until Save. A failed save
/// keeps the sheet open and marks each problem where it is.
struct SessionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [TrainingSession]

    private let sessionToEdit: TrainingSession?

    @State private var draft: SessionDraft
    @State private var sheet: Sheet?
    /// The issues found by the last save attempt. Empty until Save is tapped, so a new
    /// session doesn't open full of complaints.
    @State private var issues: [SessionDraft.Issue] = []

    private enum Sheet: Identifiable {
        case newStep(loopID: UUID?)
        case editStep(SessionStep)
        case presets
        case loop(SessionLoop)

        var id: String {
            switch self {
            case .newStep(let loopID): "new-\(loopID?.uuidString ?? "session")"
            case .editStep(let step): "edit-\(step.id.uuidString)"
            case .presets: "presets"
            case .loop(let loop): "loop-\(loop.id.uuidString)"
            }
        }
    }

    /// - Parameters:
    ///   - session: The session to change, or `nil` to create one.
    ///   - draft: What a new session starts with, for a duplicate.
    init(session: TrainingSession? = nil, startingWith draft: SessionDraft = SessionDraft()) {
        self.sessionToEdit = session
        _draft = State(initialValue: session.map { SessionDraft(session: $0) } ?? draft)
    }

    private var otherNames: [String] {
        sessions.filter { $0.id != sessionToEdit?.id }.map(\.name)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    blocks
                    addButtons
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(sessionToEdit == nil ? "New Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(sessionToEdit == nil ? "Save session" : "Save changes")
                }
            }
            .onChange(of: draft) { _, _ in
                // Once Save has complained, each message goes away as soon as it is fixed.
                if !issues.isEmpty {
                    issues = draft.issues(otherNames: otherNames)
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .newStep(let loopID):
                    StepEditorView { step in
                        withAnimation { draft.add(step, toLoop: loopID) }
                    }
                case .editStep(let step):
                    StepEditorView(step: step) { draft.update($0) }
                case .presets:
                    PresetPickerView { step in
                        withAnimation { draft.add(step) }
                    }
                case .loop(let loop):
                    LoopSettingsSheet(loop: loop) { rounds, restSeconds in
                        draft.setLoop(loop.id, rounds: rounds, restSeconds: restSeconds)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Session Name", text: $draft.name)
                .font(.title.weight(.bold))
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .accessibilityLabel("Session name")

            if let issue = issues.first(where: { $0 == .noName || $0 == .nameTaken }) {
                IssueLabel(issue: issue)
            }

            if !draft.elements.isEmpty {
                let estimate = SessionEstimate(of: draft.elements)
                Text(estimate.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SessionShapeBar(segments: estimate.segments, thickness: 10)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Blocks

    private var blocks: some View {
        VStack(spacing: 2) {
            ForEach(draft.elements) { element in
                switch element {
                case .step(let step):
                    stepBlock(step)
                case .loop(let loop):
                    loopBlock(loop)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func stepBlock(_ step: SessionStep) -> some View {
        Button {
            sheet = .editStep(step)
        } label: {
            StepBlockView(step: step)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the timer's settings")
        .reorderable(step.id, in: $draft)
    }

    private func loopBlock(_ loop: SessionLoop) -> some View {
        HStack(spacing: 2) {
            Button {
                sheet = .loop(loop)
            } label: {
                LoopRailView(rounds: loop.rounds)
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                ForEach(loop.steps) { step in
                    stepBlock(step)
                }

                VStack(spacing: 6) {
                    if issues.contains(.emptyLoop(loop.id)) {
                        IssueLabel(issue: .emptyLoop(loop.id))
                    }
                    Button("+ Timer in loop") {
                        sheet = .newStep(loopID: loop.id)
                    }
                    .buttonStyle(DashedButtonStyle(isHighlighted: issues.contains(.emptyLoop(loop.id))))
                }
                .padding(6)
                .background(Color(UIColor.systemGray5))

                Button {
                    sheet = .loop(loop)
                } label: {
                    LoopRestRowView(loop: loop)
                }
                .buttonStyle(.plain)
            }
        }
        // Lets the rail take the height of the loop's content instead of all it can get.
        .fixedSize(horizontal: false, vertical: true)
        .reorderable(loop.id, in: $draft)
    }

    // MARK: - Adding

    private var addButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("+ Timer") { sheet = .newStep(loopID: nil) }
                Button("+ Preset") { sheet = .presets }
                Button("+ Loop") {
                    withAnimation { _ = draft.addLoop() }
                }
            }
            .buttonStyle(DashedButtonStyle(isHighlighted: issues.contains(.noElements)))

            if issues.contains(.noElements) {
                IssueLabel(issue: .noElements)
            }
        }
        .padding(.top, draft.elements.isEmpty ? 0 : 12)
    }

    // MARK: - Actions

    private func save() {
        issues = draft.issues(otherNames: otherNames)
        guard issues.isEmpty else { return }
        draft.save(editing: sessionToEdit, in: modelContext)
        dismiss()
    }
}

// MARK: - Reordering

private extension View {
    /// Makes a block draggable onto the other blocks of its level, and gives it a menu
    /// with the same moves and Delete.
    ///
    /// `draggable` and `dropDestination` are the system's drag and drop: hold a block to
    /// lift it, drop it on another to take its place. What travels is the block's id as
    /// text; `SessionDraft.drop` decides whether the move is allowed.
    func reorderable(_ id: UUID, in draft: Binding<SessionDraft>) -> some View {
        self
            .draggable(id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                let before = draft.wrappedValue
                withAnimation { draft.wrappedValue.drop(dragged, onto: id) }
                return draft.wrappedValue != before
            }
            .contextMenu {
                Button("Move Up", systemImage: "arrow.up") {
                    withAnimation { draft.wrappedValue.move(id, by: -1) }
                }
                .disabled(!draft.wrappedValue.canMove(id, by: -1))

                Button("Move Down", systemImage: "arrow.down") {
                    withAnimation { draft.wrappedValue.move(id, by: 1) }
                }
                .disabled(!draft.wrappedValue.canMove(id, by: 1))

                Button("Delete", systemImage: "trash", role: .destructive) {
                    withAnimation { draft.wrappedValue.remove(id) }
                }
            }
    }
}

#Preview("New") {
    SessionEditorView()
        .modelContainer(for: [TrainingSession.self, TimerPreset.self], inMemory: true)
        .onAppear { ExerciseRepository.load() }
}
