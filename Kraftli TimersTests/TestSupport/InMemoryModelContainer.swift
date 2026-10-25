//
//  InMemoryModelContainer.swift
//  Kraftli TimersTests
//

import SwiftData
@testable import Kraftli_Timers

/// Creates an isolated in-memory SwiftData container for tests.
///
/// CloudKit sync is explicitly disabled. Without `cloudKitDatabase: .none`, the app's
/// iCloud entitlement makes SwiftData default to `.automatic` and attach CloudKit
/// mirroring even to an in-memory store. Core Data then sets up that sync on a
/// background queue, writing its own metadata to the store, and a test's `save()`
/// racing that setup throws inside Core Data and aborts the whole test process.
func makeInMemoryContainer(for models: any PersistentModel.Type...) throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    return try ModelContainer(for: Schema(models), configurations: [configuration])
}
