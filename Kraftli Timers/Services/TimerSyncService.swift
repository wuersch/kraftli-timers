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
import os

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
    /// 2. Join countdown in progress if `scheduledStartTime` is set
    /// 3. Start the timer at the scheduled time
    /// 4. Run in display-only mode (no workout logging on Watch)
    ///
    /// - Parameters:
    ///   - kind: The type of timer (EMOM or AMRAP)
    ///   - totalDuration: Total workout duration in seconds
    ///   - intervalDuration: Interval duration for EMOM timers (nil for AMRAP)
    ///   - exerciseName: Name of the exercise being performed
    ///   - scheduledStartTime: Absolute time when the timer should start (after countdown)
    ///   - correlationID: WorkoutLog ID for Watch to echo back in `WorkoutSessionEndedMessage`
    ///   - completion: Called with the result of the send operation
    func startTimerOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval?,
        exerciseName: String,
        scheduledStartTime: Date?,
        correlationID: UUID?,
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

    /// Publisher that emits when Watch sends a workout session ended message.
    /// Contains the HealthKit workout UUID and correlation ID for exact matching.
    var workoutSessionEndedReceived: AnyPublisher<WorkoutSessionEndedMessage, Never> { get }

    /// Publisher that emits when Watch starts a timer independently (Scenario D).
    /// iPhone can use this to show a mirrored timer view if desired.
    var timerStartedOnWatchReceived: AnyPublisher<TimerStartedOnWatchMessage, Never> { get }
}

// MARK: - Default Implementation

/// Default implementation using WatchConnectivityService.
final class DefaultTimerSyncService: TimerSyncService {
    private let connectivity: WatchConnectivityService
    private let timerControlSubject = PassthroughSubject<TimerControlAction, Never>()
    private let workoutSessionEndedSubject = PassthroughSubject<WorkoutSessionEndedMessage, Never>()
    private let timerStartedOnWatchSubject = PassthroughSubject<TimerStartedOnWatchMessage, Never>()

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

    var workoutSessionEndedReceived: AnyPublisher<WorkoutSessionEndedMessage, Never> {
        workoutSessionEndedSubject.eraseToAnyPublisher()
    }

    var timerStartedOnWatchReceived: AnyPublisher<TimerStartedOnWatchMessage, Never> {
        timerStartedOnWatchSubject.eraseToAnyPublisher()
    }

    func startTimerOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval?,
        exerciseName: String,
        scheduledStartTime: Date?,
        correlationID: UUID?,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let message = StartTimerMessage(
            timerKind: kind,
            totalDuration: totalDuration,
            intervalDuration: intervalDuration,
            exerciseName: exerciseName,
            displayOnly: true,  // Watch should not log workout
            scheduledStartTime: scheduledStartTime,
            correlationID: correlationID
        )

        // Dual-delivery: transferUserInfo is reliable (queued by the system and
        // delivered even when the Watch app is closed), while sendMessage provides
        // immediate delivery when the Watch is already reachable.
        // The Watch deduplicates messages that arrive via both paths.
        connectivity.transferUserInfo(message)
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

    /// Deduplication: tracks the last WorkoutSessionEndedMessage handled and when it arrived.
    /// When dual-delivery (sendMessage + transferUserInfo) is used, the same message
    /// may arrive twice. We skip duplicates within a short window.
    private var lastHandledSessionEnded: WorkoutSessionEndedMessage?
    private var lastHandledSessionEndedDate: Date?
    private static let deduplicationWindow: TimeInterval = 10

    private func handleMessage(_ message: WatchMessage) {
        switch message {
        case let controlMessage as TimerControlMessage:
            timerControlSubject.send(controlMessage.action)
        case let endedMessage as WorkoutSessionEndedMessage:
            // Deduplicate: dual-delivery may deliver the same message twice
            if let last = lastHandledSessionEnded,
               let lastDate = lastHandledSessionEndedDate,
               last == endedMessage,
               Date().timeIntervalSince(lastDate) < Self.deduplicationWindow {
                Logger.timerSync.debug("Skipping duplicate WorkoutSessionEndedMessage")
                return
            }
            lastHandledSessionEnded = endedMessage
            lastHandledSessionEndedDate = Date()
            workoutSessionEndedSubject.send(endedMessage)
        case let startedMessage as TimerStartedOnWatchMessage:
            timerStartedOnWatchSubject.send(startedMessage)
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

    var workoutSessionEndedReceived: AnyPublisher<WorkoutSessionEndedMessage, Never> {
        Empty().eraseToAnyPublisher()
    }

    var timerStartedOnWatchReceived: AnyPublisher<TimerStartedOnWatchMessage, Never> {
        Empty().eraseToAnyPublisher()
    }

    func startTimerOnWatch(
        kind: TimerKind,
        totalDuration: TimeInterval,
        intervalDuration: TimeInterval?,
        exerciseName: String,
        scheduledStartTime: Date?,
        correlationID: UUID?,
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
