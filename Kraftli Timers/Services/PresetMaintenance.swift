//
//  PresetMaintenance.swift
//  Kraftli Timers
//
//  Startup data maintenance for TimerPreset records, shared by the iPhone
//  and Watch targets: CloudKit deduplication, kept in one place for both
//  apps' entry points.
//

import Foundation
import SwiftData
import os

/// One-time startup maintenance for `TimerPreset` persistence.
///
/// Run once after the UI is up (never synchronously in `App.init`): holding the
/// SQLite write lock while the process is suspended mid-launch causes
/// `0xdead10cc` terminations, which on the Watch can drop an iPhone→Watch
/// workout handoff.
@MainActor
enum PresetMaintenance {

    /// Runs all startup maintenance. A single entry point for both apps.
    ///
    /// - Parameter deletesDuplicates: Pass `true` on the iPhone only. Restricting
    ///   deletion to a single device class makes cross-device double-deletion
    ///   structurally impossible: if both devices elected and deleted
    ///   independently they could pick different survivors and delete *both*
    ///   copies of a synced pair (issue #43). The Watch instead defers — the
    ///   iPhone's deletions sync back to it.
    static func performStartupMaintenance(in context: ModelContext, deletesDuplicates: Bool) {
        deduplicatePresets(in: context, deletesDuplicates: deletesDuplicates)
    }

    // MARK: - Deduplication

    /// Collapses presets that are *semantically identical* — same timer type,
    /// duration, reps, and exercise (see `TimerPreset.contentIdentity`) — down to
    /// a single survivor. This subsumes the CloudKit re-import case (same-UUID
    /// duplicates are byte-identical, so they share a content identity) and also
    /// removes genuinely redundant timers a user gains nothing from keeping.
    ///
    /// Only the primary device (iPhone) deletes; see `deletesDuplicates`. Note
    /// that content identity is *mutable*: a narrow race exists where one device
    /// collapses two identical presets while another is mid-editing one of them
    /// (edit not yet synced), which could drop that edit. Single-device deletion
    /// minimizes that window; it is an accepted residual risk.
    static func deduplicatePresets(in context: ModelContext, deletesDuplicates: Bool) {
        let descriptor = FetchDescriptor<TimerPreset>()
        let presets: [TimerPreset]
        do {
            presets = try context.fetch(descriptor)
        } catch {
            Logger.data.error("Preset dedup fetch failed: \(error)")
            return
        }

        let losers = duplicatesToDelete(among: presets, deletesDuplicates: deletesDuplicates)
        guard !losers.isEmpty else { return }

        for loser in losers {
            context.delete(loser)
        }
        Logger.data.info("Deduplicated presets: deleted \(losers.count) redundant copies")

        do {
            try context.save()
        } catch {
            Logger.data.error("Preset dedup save failed: \(error)")
        }
    }

    /// Pure dedup decision: the redundant presets that should be deleted (every
    /// member of each identical-content group except its elected survivor).
    /// Returns `[]` when `deletesDuplicates` is `false` — the non-primary (Watch)
    /// device defers all deletion so two devices can never cross-delete both
    /// copies of a synced pair. Internal so it can be unit-tested without a store.
    static func duplicatesToDelete(among presets: [TimerPreset], deletesDuplicates: Bool) -> [TimerPreset] {
        guard deletesDuplicates else { return [] }

        let duplicateGroups = Dictionary(grouping: presets, by: \.contentIdentity)
            .filter { $0.value.count > 1 }

        return duplicateGroups.values.flatMap { candidates -> [TimerPreset] in
            let survivor = electSurvivor(among: candidates)
            return candidates.filter { $0 !== survivor }
        }
    }

    /// Deterministically elects the surviving preset among identical-content
    /// duplicates by lowest `id` UUID. The `id` is immutable and CloudKit-synced,
    /// so every device elects the *same* survivor regardless of fetch order —
    /// the property that makes deletion safe from cross-device data loss.
    /// Internal (not private) so tests can assert permutation-independence.
    static func electSurvivor(among candidates: [TimerPreset]) -> TimerPreset {
        candidates.min { $0.id.uuidString < $1.id.uuidString }!
    }

    // MARK: - Sort order

    /// Collision-free `sortOrder` for a newly created preset.
    ///
    /// Using `presets.count` collides after deletions (deletes don't renormalize),
    /// so two presets can share a `sortOrder` and diverge in list order per device.
    static func nextSortOrder(after presets: [TimerPreset]) -> Int {
        (presets.map(\.sortOrder).max() ?? -1) + 1
    }
}
