//
//  TimerProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import Foundation

protocol TimerProvider {
    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping (Any) -> Void) -> Any
    func invalidateTimer(_ timer: Any)
}


