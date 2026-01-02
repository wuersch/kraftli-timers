//
//  FoundationTimerProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

final class FoundationTimerProvider: TimerProvider {
    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping (Any) -> Void) -> Any {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
    }
    
    func invalidateTimer(_ timer: Any) {
        (timer as? Timer)?.invalidate()
    }
}
