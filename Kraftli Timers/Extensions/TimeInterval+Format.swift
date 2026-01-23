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

    /// Returns duration in readable form: "20 min", "30 sec", or "1 min 30 sec".
    var durationText: String {
        let totalSeconds = max(0, Int(self))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes == 0 {
            return "\(seconds) sec"
        } else if seconds == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes) min \(seconds) sec"
        }
    }

    /// Returns interval description: "30s interval" or "1m 30s interval".
    /// Use `compact: true` for Watch (shorter format).
    func intervalDescription(compact: Bool = false) -> String {
        let seconds = self
        if seconds >= 60 {
            let mins = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            if secs == 0 {
                return compact ? "\(mins)m interval" : "\(mins) min per interval"
            }
            return compact ? "\(mins)m \(secs)s interval" : "\(mins) min \(secs) sec per interval"
        }
        return compact ? "\(Int(seconds))s interval" : "\(Int(seconds)) sec per interval"
    }
}
