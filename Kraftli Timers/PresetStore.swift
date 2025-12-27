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
        presets = presets.enumerated().filter { !indices.contains($0.offset) }.map(\.element)
    }

    func deletePreset(_ preset: TimerPreset) {
        presets.removeAll { $0.id == preset.id }
    }

    func movePreset(from source: IndexSet, to destination: Int) {
        // Extract items to move
        let itemsToMove = source.sorted().map { presets[$0] }
        
        // Calculate adjusted destination before removal
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        
        // Remove items in reverse order to maintain indices
        source.sorted().reversed().forEach { presets.remove(at: $0) }
        
        // Insert items at new position
        presets.insert(contentsOf: itemsToMove, at: adjustedDestination)
    }
}
