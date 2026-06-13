import Foundation

enum VideoTimestampFormatter {
    static func string(from seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours):\(twoDigit(minutes)):\(twoDigit(remainingSeconds))"
        }

        return "\(minutes):\(twoDigit(remainingSeconds))"
    }

    static func seconds(from text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count else { return nil }

        if values.contains(where: { $0 < 0 }) {
            return nil
        }

        if values.count == 2 {
            let minutes = values[0]
            let seconds = values[1]
            guard seconds < 60 else { return nil }
            return TimeInterval(minutes * 60 + seconds)
        }

        let hours = values[0]
        let minutes = values[1]
        let seconds = values[2]
        guard minutes < 60, seconds < 60 else { return nil }
        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
