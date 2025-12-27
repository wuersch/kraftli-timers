//
//  TimerPresetsView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 24.12.2025.
//

import SwiftUI

struct TimerPresetView: View {
    @Environment(TimerPresetStore.self) private var store
    @State private var presetToEdit: TimerPreset?
    @State private var presetToRun: TimerPreset?
    @State private var isEditMode = false
    @State private var showingAddPreset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.presets) { preset in
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
                                .accessibilityLabel("Start \(preset.exercise.name) timer")
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
                    .onDelete { indices in
                        store.deleteTimerPreset(at: indices)
                    }
                    .onMove(perform: isEditMode ? { source, destination in
                        store.moveTimerPreset(from: source, to: destination)
                    } : nil)
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
                    if let targetReps = preset.targetReps {
                        let totalSeconds = TimeInterval(preset.duration.components.seconds)
                        let intervalSeconds = totalSeconds / Double(targetReps)

                        EMOMTimerView(timerModel: EMOMTimerModel(
                            totalDuration: totalSeconds,
                            intervalDuration: intervalSeconds
                        ))
                        .navigationTitle("\(preset.exercise.name) ⸱ \(preset.kind.rawValue)")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                case .amrap:
                    let totalSeconds = TimeInterval(preset.duration.components.seconds)
                    AMRAPTimerView(timerModel: AMRAPTimerModel(totalDuration: totalSeconds))
                        .navigationTitle("\(preset.exercise.name) ⸱ \(preset.kind.rawValue)")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

#Preview {
    TimerPresetView()
}
