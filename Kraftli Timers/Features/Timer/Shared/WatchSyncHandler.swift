//
//  WatchSyncHandler.swift
//  Kraftli Timers
//
//  Handles Apple Watch sync subscription and control message routing.
//  Centralizes the Combine subscription logic used by timer views.
//

#if os(iOS)
import Foundation
import Combine

/// Callbacks for handling remote control actions from Apple Watch.
///
/// Timer views provide these callbacks to respond to Watch commands.
/// The handler routes incoming messages to the appropriate callback.
struct WatchSyncCallbacks {
    /// Called when Watch sends play command (resume or start timer).
    let onPlay: () -> Void

    /// Called when Watch sends pause command.
    let onPause: () -> Void

    /// Called when Watch sends stop command (dismiss timer).
    let onStop: () -> Void

    /// Called when Watch sends increment round command (AMRAP only).
    /// Defaults to no-op for EMOM timers.
    let onIncrementRound: () -> Void

    init(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onIncrementRound: @escaping () -> Void = {}
    ) {
        self.onPlay = onPlay
        self.onPause = onPause
        self.onStop = onStop
        self.onIncrementRound = onIncrementRound
    }
}

/// Handles Apple Watch timer control message subscription.
///
/// Creates and manages the Combine subscription for receiving control messages
/// from the Apple Watch and routes them to the appropriate callbacks.
///
/// ## Usage
/// ```swift
/// @State private var cancellables = Set<AnyCancellable>()
///
/// .onAppear {
///     WatchSyncHandler.setupSubscription(
///         syncService: syncService,
///         callbacks: WatchSyncCallbacks(
///             onPlay: { startCountdown() },
///             onPause: { timerModel.pause() },
///             onStop: { dismiss() }
///         ),
///         cancellables: &cancellables
///     )
/// }
/// ```
enum WatchSyncHandler {
    /// Sets up subscription to receive control messages from Apple Watch.
    ///
    /// - Parameters:
    ///   - syncService: The timer sync service (nil if Watch sync not available).
    ///   - callbacks: Callbacks to handle each control action.
    ///   - cancellables: Set to store the subscription for lifecycle management.
    @MainActor
    static func setupSubscription(
        syncService: TimerSyncService?,
        callbacks: WatchSyncCallbacks,
        cancellables: inout Set<AnyCancellable>
    ) {
        syncService?.timerControlReceived
            .receive(on: DispatchQueue.main)
            .sink { action in
                switch action {
                case .play:
                    callbacks.onPlay()
                case .pause:
                    callbacks.onPause()
                case .stop:
                    callbacks.onStop()
                case .incrementRound:
                    callbacks.onIncrementRound()
                }
            }
            .store(in: &cancellables)
    }
}
#endif
