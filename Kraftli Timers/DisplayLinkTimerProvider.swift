//
//  DisplayLinkTimerProvider.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 20.12.2025.
//

import QuartzCore

final class DisplayLinkTimerProvider: TimerProvider {
    // Ignores `interval` and `repeats`; ticks at the display's refresh rate (via CADisplayLink).
    func scheduleTimer(
        interval: TimeInterval,
        repeats: Bool,
        block: @escaping (Any) -> Void
    ) -> Any {
        let displayLink = CADisplayLink(
            target: DisplayLinkTarget(block: { timer in
                block(timer)
            }),
            selector: #selector(DisplayLinkTarget.fire)
        )
        if #available(iOS 15.0, *) {
              displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        }
        displayLink.add(to: .main, forMode: .common)
        return displayLink
    }

    func invalidateTimer(_ timer: Any) {
        (timer as? CADisplayLink)?.invalidate()
    }
}

private class DisplayLinkTarget {
    let block: (Any) -> Void

    init(block: @escaping (Any) -> Void) {
        self.block = block
    }

    @objc func fire(displayLink: CADisplayLink) {
        block(displayLink)
    }
}
