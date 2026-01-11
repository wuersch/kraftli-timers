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
            List {
                ForEach(presets) { preset in
                    TimerPresetRow(
                        preset: preset,
                        didTapRun: { presetToRun = $0 },
                        didTapEdit: { activeSheet = .edit($0) }
                    )
                    .cardListRow()
                }
                .onDelete(perform: deletePresets)
                .onMove(perform: movePresets)
            }
            .cardListStyle(isEmpty: presets.isEmpty)
            .overlay {
                if presets.isEmpty {
                    ContentUnavailableView(
                        "No Timers",
                        systemImage: "timer",
                        description: Text("Tap + to create your first timer")
                    )
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



#Preview {
    TimerPresetView()
        .modelContainer(for: [TimerPreset.self, Exercise.self], inMemory: true)
}

