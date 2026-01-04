//
//  TimerPresetView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 24.12.2025.
//

import SwiftUI
import SwiftData

enum ActiveSheet: Identifiable {
    case add
    case edit(TimerPreset)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let preset): preset.id.uuidString
        }
    }
}

struct TimerPresetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    @State private var activeSheet: ActiveSheet?
    @State private var presetToRun: TimerPreset?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Group {
                if presets.isEmpty {
                    ContentUnavailableView(
                        "No Timers",
                        systemImage: "timer",
                        description: Text("Tap + to create your first timer")
                    )
                } else {
                    List {
                        ForEach(presets) { preset in
                            TimerPresetRow(
                                preset: preset,
                                onRun: { presetToRun = $0 },
                                onEdit: { activeSheet = .edit($0) }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(
                                EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
                            )
                        }
                        .onDelete(perform: deletePresets)
                        .onMove(perform: movePresets)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Timers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !presets.isEmpty {
                        Button {
                            withAnimation {
                                editMode = (editMode == .active) ? .inactive : .active
                            }
                        } label: {
                            Text(editMode == .active ? "Done" : "Edit")
                        }
                        .accessibilityLabel(editMode == .active ? "Done editing" : "Edit timers")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new timer")
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    TimerPresetEditorView()
                case .edit(let preset):
                    TimerPresetEditorView(presetToEdit: preset)
                }
            }
            .onChange(of: presets.isEmpty) { _, isEmpty in
                if isEmpty {
                    editMode = .inactive
                }
            }
        }
        .fullScreenCover(item: $presetToRun) { preset in
            TimerRunnerView(preset: preset)
        }
    }

    // MARK: - Actions

    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(presets[index])
        }
    }

    private func movePresets(from source: IndexSet, to destination: Int) {
        var reorderedPresets = presets
        reorderedPresets.move(fromOffsets: source, toOffset: destination)

        for (index, preset) in reorderedPresets.enumerated() {
            preset.sortOrder = index
        }
    }
}

struct TimerPresetRow: View {
    @Environment(\.editMode) private var editMode
    
    let preset: TimerPreset
    let onRun: (TimerPreset) -> Void
    let onEdit: (TimerPreset) -> Void

    private var isEditing: Bool {
        editMode?.wrappedValue == .active
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.primaryText).font(.headline).fontWeight(.semibold)
                Text(preset.secondaryText).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if !isEditing {
                Button {
                    onRun(preset)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(preset.exercise?.name ?? "Timer")")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { onEdit(preset) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.primaryText), \(preset.secondaryText)")
    }
}

#Preview {
    TimerPresetView()
        .modelContainer(for: [TimerPreset.self, Exercise.self], inMemory: true)
}

