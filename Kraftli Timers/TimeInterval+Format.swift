import Foundation

extension TimeInterval {
    /// Returns the time formatted as mm:ss, clamped at 0 for negatives.
    var mmSS: String {
        let totalSeconds = max(0, Int(self))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
