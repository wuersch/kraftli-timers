//
//  PresetStore.swift
//  Kraftli Timers
//
//  Created by Claude on 26.12.2025.
//

import Foundation

@Observable
class PresetStore {
    var presets: [TimerPreset]

    init(presets: [TimerPreset] = TimerPreset.defaults) {
        self.presets = presets
    }

    // MARK: - Preset Management

    func addPreset(_ preset: TimerPreset) {
        presets.append(preset)
    }

    func updatePreset(_ updatedPreset: TimerPreset) {
        if let index = presets.firstIndex(where: { $0.id == updatedPreset.id }) {
            presets[index] = updatedPreset
        }
    }

    func deletePreset(at indices: IndexSet) {
        var presetsToKeep: [TimerPreset] = []
        for (index, preset) in presets.enumerated() {
            if !indices.contains(index) {
                presetsToKeep.append(preset)
            }
        }
        presets = presetsToKeep
    }

    func deletePreset(_ preset: TimerPreset) {
        presets.removeAll { $0.id == preset.id }
    }

    func movePreset(from source: IndexSet, to destination: Int) {
        var updatedPresets = presets

        // Extract items to move
        let itemsToMove = source.sorted().map { updatedPresets[$0] }

        // Remove items (in reverse order to maintain indices)
        for index in source.sorted().reversed() {
            updatedPresets.remove(at: index)
        }

        // Calculate adjusted destination
        let adjustedDestination = destination - source.filter { $0 < destination }.count

        // Insert items at new position
        for (offset, item) in itemsToMove.enumerated() {
            updatedPresets.insert(item, at: adjustedDestination + offset)
        }

        presets = updatedPresets
    }
}
