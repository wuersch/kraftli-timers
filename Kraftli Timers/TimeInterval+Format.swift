import Foundation

extension TimeInterval {
    /// Returns the time formatted as mm:ss, clamped at 0 for negatives.
    var mmSS: String {
        let totalSeconds = max(0, Int(self))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Returns the time formatted as hh:mm:ss for durations over 1 hour.
    var hhMMSS: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// Returns time formatted intelligently: mm:ss for <1h, hh:mm:ss for ≥1h.
    var formatted: String {
        self >= 3600 ? hhMMSS : mmSS
    }
}
