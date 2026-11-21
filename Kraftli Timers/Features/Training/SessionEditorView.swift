//
//  SessionEditorView.swift
//  Kraftli Timers
//
//  The block editor for a training session (UC-0013).
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
    /// The block being dragged, noted when the drag starts.
    @State private var draggedID: UUID?
    /// Where the dragged block would land if it were dropped now; a line marks the place.
    @State private var dropPlace: SessionDraft.Place?

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
            StepBlockView(step: step, trailingInset: BlockMenu.width)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the timer's settings")
        .overlay(alignment: .trailing) {
            BlockMenu(id: step.id, name: step.exerciseName, draft: $draft)
        }
        .modifier(reorderable(step.id))
    }

    private func loopBlock(_ loop: SessionLoop) -> some View {
        HStack(spacing: 2) {
            Button {
                sheet = .loop(loop)
            } label: {
                LoopRailView(rounds: loop.rounds)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Changes rounds and rest")
            .overlay(alignment: .bottom) {
                BlockMenu(id: loop.id, name: "loop", draft: $draft)
            }

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
                // A timer dropped here joins the loop as its last timer.
                .onDrop(of: [.text], delegate: dropDelegate { _ in .endOfLoop(loop.id) })
                .overlay(alignment: .top) {
                    if dropPlace == .endOfLoop(loop.id) { DropLine() }
                }

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
        .modifier(reorderable(loop.id))
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

private extension SessionEditorView {
    func reorderable(_ id: UUID) -> Reorderable {
        Reorderable(id: id, draggedID: $draggedID, dropPlace: $dropPlace) { place in
            dropDelegate(place)
        }
    }

    /// - Parameter place: The place a drop at that point of the view stands for.
    func dropDelegate(_ place: @escaping (CGPoint) -> SessionDraft.Place) -> BlockDropDelegate {
        BlockDropDelegate(place: place, draft: $draft, draggedID: $draggedID, dropPlace: $dropPlace)
    }
}

/// Makes a block draggable, and the gaps above and below it places to drop a block.
///
/// A block dropped on the upper half of another lands before it, on the lower half after
/// it; a line shows which while the block is still being dragged.
///
/// This uses `onDrag` and `onDrop(of:delegate:)` instead of the simpler `draggable` and
/// `dropDestination`: only a `DropDelegate` is told where the finger is during the drag,
/// and `onDrag` says when a drag starts, so the editor can remember the dragged block
/// instead of unpacking it from the drop.
///
/// The block has no `contextMenu`: that also starts with a long press, and where both
/// are attached the menu opens first and the drag is cancelled. The menu is a button of
/// its own instead (`BlockMenu`).
private struct Reorderable: ViewModifier {
    let id: UUID
    @Binding var draggedID: UUID?
    @Binding var dropPlace: SessionDraft.Place?
    let dropDelegate: (@escaping (CGPoint) -> SessionDraft.Place) -> BlockDropDelegate

    /// The block's height, to tell its upper half from its lower.
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .onDrag {
                draggedID = id
                return NSItemProvider(object: id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: dropDelegate { location in
                location.y < height / 2 ? .before(id) : .after(id)
            })
            .overlay(alignment: .top) {
                if dropPlace == .before(id) { DropLine() }
            }
            .overlay(alignment: .bottom) {
                if dropPlace == .after(id) { DropLine() }
            }
    }
}

/// Follows a drag over one drop target. Where targets are nested, the innermost one
/// under the finger is asked.
private struct BlockDropDelegate: DropDelegate {
    let place: (CGPoint) -> SessionDraft.Place
    @Binding var draft: SessionDraft
    @Binding var draggedID: UUID?
    @Binding var dropPlace: SessionDraft.Place?

    /// The place a drop would go to now, or `nil` when it would change nothing.
    private func target(_ info: DropInfo) -> SessionDraft.Place? {
        guard let draggedID else { return nil }
        let place = draft.resolved(place(info.location), for: draggedID)
        return draft.canDrop(draggedID, at: place) ? place : nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedID != nil
    }

    func dropEntered(info: DropInfo) {
        dropPlace = target(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dropPlace = target(info)
        // `.move` keeps the system from showing the green "+" of a copy.
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        dropPlace = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropPlace = nil
            draggedID = nil
        }
        guard let draggedID, let place = target(info) else { return false }
        withAnimation { draft.drop(draggedID, at: place) }
        return true
    }
}

/// The line that marks where a dragged block would land.
private struct DropLine: View {
    var body: some View {
        Capsule()
            .fill(.tint)
            .frame(height: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The "…" button on a block: moving it without dragging, and Delete.
private struct BlockMenu: View {
    /// The width the button takes up on a block's trailing edge.
    static let width: CGFloat = 44

    let id: UUID
    /// What the block is called in the accessibility label: the exercise, or "loop".
    let name: String
    @Binding var draft: SessionDraft

    var body: some View {
        Menu {
            Button("Move Up", systemImage: "arrow.up") {
                withAnimation { draft.move(id, by: -1) }
            }
            .disabled(!draft.canMove(id, by: -1))

            Button("Move Down", systemImage: "arrow.down") {
                withAnimation { draft.move(id, by: 1) }
            }
            .disabled(!draft.canMove(id, by: 1))

            // Only there for a timer in a loop or right next to one.
            ForEach(draft.loopMoves(for: id), id: \.self) { loopMove in
                Button(loopMove.title, systemImage: loopMove.systemImage) {
                    withAnimation { draft.move(id, loopMove) }
                }
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                withAnimation { draft.remove(id) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: Self.width, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions for \(name)")
    }
}

private extension SessionDraft.LoopMove {
    var title: String {
        switch self {
        case .intoLoopAbove: "Move into Loop Above"
        case .intoLoopBelow: "Move into Loop Below"
        case .outOfLoop: "Move out of Loop"
        }
    }

    var systemImage: String {
        switch self {
        case .intoLoopAbove: "arrow.turn.right.up"
        case .intoLoopBelow: "arrow.turn.right.down"
        case .outOfLoop: "arrow.turn.up.left"
        }
    }
}
