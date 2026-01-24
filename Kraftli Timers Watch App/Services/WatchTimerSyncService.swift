//
//  WatchTimerSyncService.swift
//  Kraftli Timers Watch App
//
//  Service for sending timer control messages from Watch to iPhone.
//  Used when a mirrored timer (started from iPhone) is controlled on Watch.
//

import Foundation
import Combine

// MARK: - Protocol

/// Service for sending timer control messages from Watch to iPhone.
///
/// Use this protocol to send play/pause/stop commands to iPhone
/// when controlling a mirrored timer on Watch.
protocol WatchTimerSyncService {
    /// Whether the iPhone is currently reachable for immediate communication.
    var isPhoneReachable: Bool { get }

    /// Sends a timer control command to iPhone.
    ///
    /// - Parameters:
    ///   - action: The control action (play, pause, stop)
    ///   - completion: Called with the result of the send operation
    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)?
    )

    /// Publisher that emits when a control message is received from iPhone.
    var timerControlReceived: AnyPublisher<TimerControlAction, Never> { get }
}

// MARK: - Default Implementation

/// Default implementation using WatchConnectivityService.
///
/// Note: This service no longer sets up its own message handler.
/// The WatchMessageCoordinator handles message routing and forwards
/// control messages via `handleControlMessage(_:)`.
final class DefaultWatchTimerSyncService: WatchTimerSyncService {
    private let connectivity: WatchConnectivityService
    private let timerControlSubject = PassthroughSubject<TimerControlAction, Never>()

    init(connectivity: WatchConnectivityService = .shared) {
        self.connectivity = connectivity
    }

    var isPhoneReachable: Bool {
        connectivity.isReachable
    }

    var timerControlReceived: AnyPublisher<TimerControlAction, Never> {
        timerControlSubject.eraseToAnyPublisher()
    }

    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = TimerControlMessage(action: action)
        connectivity.sendMessage(message, completion: completion)
    }

    // MARK: - Internal (for WatchMessageCoordinator)

    /// Handles a control message forwarded from the coordinator.
    func handleControlMessage(_ message: TimerControlMessage) {
        timerControlSubject.send(message.action)
    }
}

// MARK: - Silent Implementation

/// Silent implementation that does nothing. Useful for standalone Watch timers.
final class SilentWatchTimerSyncService: WatchTimerSyncService {
    var isPhoneReachable: Bool { false }

    var timerControlReceived: AnyPublisher<TimerControlAction, Never> {
        Empty().eraseToAnyPublisher()
    }

    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op for standalone timers
    }
}
