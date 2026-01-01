//
//  TimerPresetsView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 24.12.2025.
//

import SwiftUI
import SwiftData

struct TimerPresetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerPreset.sortOrder) private var presets: [TimerPreset]

    @State private var presetToEdit: TimerPreset?
    @State private var presetToRun: TimerPreset?
    @State private var isEditMode = false
    @State private var showingAddPreset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(presets) { preset in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.primaryText)
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text(preset.secondaryText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            if !isEditMode {
                                Button(action: {
                                    presetToRun = preset
                                }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.tint)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Start \(preset.exercise?.name ?? "timer")")
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                presetToEdit = preset
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(preset.primaryText), \(preset.secondaryText)")
                    }
                    .onDelete(perform: deletePresets)
                    .onMove(perform: movePresets)
                } header: {
                    Spacer()
                }
            }
            .navigationTitle("Timers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                    }
                    .accessibilityLabel(isEditMode ? "Done editing" : "Edit timers")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPreset = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new timer")
                }
            }
            .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
            .sheet(isPresented: $showingAddPreset) {
                TimerPresetEditorView()
            }
            .sheet(item: $presetToEdit) { preset in
                TimerPresetEditorView(presetToEdit: preset)
            }
        }
        .fullScreenCover(item: $presetToRun) { preset in
            NavigationStack {
                switch preset.kind {
                case .emom:
                    // targetReps guaranteed by TimerPreset.init precondition
                    let intervalSeconds = preset.durationInterval / Double(preset.targetReps!)

                    EMOMTimerView(timerModel: EMOMTimerModel(
                        totalDuration: preset.durationInterval,
                        intervalDuration: intervalSeconds
                    ))
                    .navigationTitle("\(preset.exercise?.name ?? "Timer") ⸱ \(preset.kind.rawValue)")
                    .navigationBarTitleDisplayMode(.inline)
                case .amrap:
                    AMRAPTimerView(timerModel: AMRAPTimerModel(totalDuration: preset.durationInterval))
                        .navigationTitle("\(preset.exercise?.name ?? "Timer") ⸱ \(preset.kind.rawValue)")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
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
