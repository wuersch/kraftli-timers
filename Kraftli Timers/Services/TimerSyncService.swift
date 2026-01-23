//
//  TimerSyncService.swift
//  Kraftli Timers
//
//  High-level service for syncing timer state to Apple Watch.
//  Abstracts WatchConnectivity details from the view layer.
//
//  Future extensions:
//  - HealthKit workout session coordination
//  - Heart rate data requests
//  - Bidirectional workout metrics sync
//

#if os(iOS)
import Foundation
import Combine

// MARK: - Protocol

/// Service for synchronizing timer state with Apple Watch.
///
/// Use this protocol to send timer commands to the Watch without
/// coupling views directly to WatchConnectivity.
protocol TimerSyncService {
    /// Whether the Watch is currently reachable for immediate communication.
    var isWatchReachable: Bool { get }

    /// Publisher that emits when watch reachability changes.
    var isWatchReachablePublisher: AnyPublisher<Bool, Never> { get }

    /// Sends a "start timer" command to the Watch.
    ///
    /// When the Watch receives this message, it will:
    /// 1. Present the appropriate timer view (EMOM or AMRAP)
    /// 2. Start the timer immediately
    /// 3. Run in display-only mode (no workout logging on Watch)
    ///
    /// - Parameters:
    ///   - kind: The type of timer (EMOM or AMRAP)
    ///   - totalDuration: Total workout duration in seconds
    ///   - intervalDuration: Interval duration for EMOM timers (nil for AMRAP)
    ///   - exerciseName: Name of the exercise being performed
    ///   - completion: Called with the result of the send operation
    func startTimerOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval?,
        exerciseName: String,
        completion: ((Result<Void, Error>) -> Void)?
    )

    /// Sends a timer control command to the Watch.
    ///
    /// Used to synchronize play/pause/stop actions on mirrored timers.
    ///
    /// - Parameters:
    ///   - action: The control action (play, pause, stop)
    ///   - completion: Called with the result of the send operation
    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)?
    )

    /// Publisher that emits when a control message is received from Watch.
    var timerControlReceived: AnyPublisher<TimerControlAction, Never> { get }
}

// MARK: - Default Implementation

/// Default implementation using WatchConnectivityService.
final class DefaultTimerSyncService: TimerSyncService {
    private let connectivity: WatchConnectivityService
    private let timerControlSubject = PassthroughSubject<TimerControlAction, Never>()

    init(connectivity: WatchConnectivityService = .shared) {
        self.connectivity = connectivity
        setupMessageHandling()
    }

    var isWatchReachable: Bool {
        connectivity.isReachable
    }

    var isWatchReachablePublisher: AnyPublisher<Bool, Never> {
        connectivity.$isReachable.eraseToAnyPublisher()
    }

    var timerControlReceived: AnyPublisher<TimerControlAction, Never> {
        timerControlSubject.eraseToAnyPublisher()
    }

    func startTimerOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval?,
        exerciseName: String,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = StartTimerMessage(
            timerKind: kind,
            totalDuration: totalDuration,
            intervalDuration: intervalDuration,
            exerciseName: exerciseName,
            displayOnly: true  // Watch should not log workout
        )

        connectivity.sendMessage(message, completion: completion)
    }

    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = TimerControlMessage(action: action)
        connectivity.sendMessage(message, completion: completion)
    }

    // MARK: - Private

    private func setupMessageHandling() {
        connectivity.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
    }

    private func handleMessage(_ message: WatchMessage) {
        switch message {
        case let controlMessage as TimerControlMessage:
            timerControlSubject.send(controlMessage.action)
        default:
            break
        }
    }
}

// MARK: - Silent Implementation (for testing/previews)

/// Silent implementation that does nothing. Useful for tests and previews.
final class SilentTimerSyncService: TimerSyncService {
    var isWatchReachable: Bool { false }

    var isWatchReachablePublisher: AnyPublisher<Bool, Never> {
        Just(false).eraseToAnyPublisher()
    }

    var timerControlReceived: AnyPublisher<TimerControlAction, Never> {
        Empty().eraseToAnyPublisher()
    }

    func startTimerOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval?,
        exerciseName: String,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op
    }

    func sendTimerControl(
        _ action: TimerControlAction,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        // No-op
    }
}
#endif
