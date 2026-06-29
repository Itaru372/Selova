import Foundation

@MainActor
enum StudyProgress {
    struct AttentionGap: Identifiable {
        let video: VideoItem
        let startTime: TimeInterval
        let endTime: TimeInterval
        let scrollCount: Int

        var id: String {
            "\(video.id.uuidString)-\(Int(startTime.rounded()))-\(Int(endTime.rounded()))"
        }

        var rangeText: String {
            "\(compactPlaybackPosition(startTime))〜\(compactPlaybackPosition(endTime))"
        }
    }

    static func lastPlaybackPosition(for video: VideoItem) -> TimeInterval {
        guard let playbackTime = video.lastPlaybackTime, playbackTime.isFinite, playbackTime > 0 else {
            return 0
        }
        return playbackTime
    }

    static func progress(for video: VideoItem) -> Double {
        guard video.duration > 0 else { return 0 }
        return min(max(lastPlaybackPosition(for: video) / video.duration, 0), 1)
    }

    static func isCompleted(_ video: VideoItem) -> Bool {
        guard video.duration > 0 else {
            return (video.completionCount ?? 0) > 0
        }
        return (video.completionCount ?? 0) > 0 || progress(for: video) >= 0.995
    }

    static func attentionGaps(for video: VideoItem) -> [AttentionGap] {
        guard isCompleted(video) else { return [] }

        let eventTimes = (video.attentionEvents ?? [])
            .map(\.playbackTime)
            .filter { $0.isFinite && $0 >= 0 }
            .sorted()
        guard eventTimes.count >= 2 else { return [] }

        var clusters = [[TimeInterval]]()
        for eventTime in eventTimes {
            if let last = clusters.indices.last,
               let lastTime = clusters[last].last,
               eventTime - lastTime <= 90 {
                clusters[last].append(eventTime)
            } else {
                clusters.append([eventTime])
            }
        }

        return clusters.compactMap { cluster in
            guard cluster.count >= 2,
                  let first = cluster.first,
                  let last = cluster.last else {
                return nil
            }
            let start = max(0, first - 30)
            let end = video.duration > 0
                ? min(video.duration, last + 45)
                : last + 45
            return AttentionGap(
                video: video,
                startTime: start,
                endTime: max(start + 1, end),
                scrollCount: cluster.count
            )
        }
    }

    static func attentionRecommendations(from videos: [VideoItem]) -> [AttentionGap] {
        videos
            .flatMap(attentionGaps(for:))
            .sorted {
                if $0.scrollCount == $1.scrollCount {
                    return ($0.video.lastWatchedAt ?? .distantPast) > ($1.video.lastWatchedAt ?? .distantPast)
                }
                return $0.scrollCount > $1.scrollCount
            }
    }

    static func playbackPositionText(for video: VideoItem) -> String {
        let playbackTime = lastPlaybackPosition(for: video)
        guard playbackTime > 0 else { return "未視聴" }

        if video.duration > 0 {
            return "\(formattedPlaybackPosition(playbackTime))まで / \(formattedPlaybackPosition(video.duration))"
        }
        return "\(formattedPlaybackPosition(playbackTime))まで"
    }

    static func compactPlaybackPositionText(for video: VideoItem) -> String {
        let playbackTime = lastPlaybackPosition(for: video)
        guard playbackTime > 0 else { return "未視聴" }

        if video.duration > 0 {
            return "\(compactPlaybackPosition(playbackTime)) / \(compactPlaybackPosition(video.duration))"
        }
        return compactPlaybackPosition(playbackTime)
    }

    static func localizedCompactPlaybackPositionText(for video: VideoItem) -> String {
        let playbackTime = lastPlaybackPosition(for: video)
        guard playbackTime > 0 else { return String(localized: "未視聴") }

        if video.duration > 0 {
            return "\(compactPlaybackPosition(playbackTime)) / \(compactPlaybackPosition(video.duration))"
        }
        return compactPlaybackPosition(playbackTime)
    }

    static func localizedPlaybackPositionText(for video: VideoItem) -> String {
        let playbackTime = lastPlaybackPosition(for: video)
        guard playbackTime > 0 else { return String(localized: "未視聴") }

        if video.duration > 0 {
            return String(
                localized: "\(localizedPlaybackPosition(playbackTime))まで / \(localizedPlaybackPosition(video.duration))",
                comment: "Playback position label. First value is the current position, second is the full duration."
            )
        }
        return String(
            localized: "\(localizedPlaybackPosition(playbackTime))まで",
            comment: "Playback position label when the full duration is unknown."
        )
    }

    static func statusText(for video: VideoItem) -> String {
        let progress = progress(for: video)
        if progress >= 0.9 {
            return "あと少し"
        }
        if lastPlaybackPosition(for: video) > 0 {
            return "続きから"
        }
        if Calendar.current.dateComponents([.day], from: video.createdAt, to: Date()).day ?? 0 <= 2 {
            return "最近追加"
        }
        if let lastWatchedAt = video.lastWatchedAt,
           Calendar.current.dateComponents([.day], from: lastWatchedAt, to: Date()).day ?? 0 >= 7 {
            return "再開候補"
        }
        return "未視聴"
    }

    static func localizedStatusText(for video: VideoItem) -> String {
        switch statusText(for: video) {
        case "あと少し":
            return String(localized: "あと少し")
        case "続きから":
            return String(localized: "続きから")
        case "最近追加":
            return String(localized: "最近追加")
        case "再開候補":
            return String(localized: "再開候補")
        default:
            return String(localized: "未視聴")
        }
    }

    static func durationText(for video: VideoItem) -> String? {
        guard video.duration > 0 else { return nil }
        let totalSeconds = Int(video.duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func recommendationScore(
        for video: VideoItem,
        now: Date = Date(),
        focusFolderID: UUID? = nil
    ) -> Double {
        let progress = progress(for: video)
        var score: Double = 0

        if progress >= 0.9 && progress < 1 {
            score += 105
        } else if progress > 0 && progress < 0.9 {
            score += 70
        } else {
            score += 20
        }

        if let lastWatchedAt = video.lastWatchedAt {
            let days = Calendar.current.dateComponents([.day], from: lastWatchedAt, to: now).day ?? 0
            if days >= 7 {
                score += min(45, 24 + Double(days))
            } else {
                score += max(0, 22 - Double(days * 3))
            }
        } else {
            let daysSinceCreated = Calendar.current.dateComponents([.day], from: video.createdAt, to: now).day ?? 0
            score += max(0, 32 - Double(daysSinceCreated * 4))
        }

        let minutesSinceCreated = Calendar.current.dateComponents([.minute], from: video.createdAt, to: now).minute ?? 0
        if progress == 0 && minutesSinceCreated >= 0 && minutesSinceCreated <= 60 {
            score += 90
        }

        if let focusFolderID,
           let folderID = video.folder?.id,
           folderID == focusFolderID {
            score += 18
        } else if video.folder != nil {
            score += 6
        }

        if video.type == .local {
            score += 4
        }
        return score
    }

    static func formattedPlaybackPosition(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        if minutes == 0 {
            return "\(remainingSeconds)秒"
        }
        if remainingSeconds == 0 {
            return "\(minutes)分"
        }
        return "\(minutes)分\(remainingSeconds)秒"
    }

    static func localizedPlaybackPosition(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        if minutes == 0 {
            return String(localized: "\(remainingSeconds)秒", comment: "Playback time in seconds.")
        }
        if remainingSeconds == 0 {
            return String(localized: "\(minutes)分", comment: "Playback time in minutes.")
        }
        return String(localized: "\(minutes)分\(remainingSeconds)秒", comment: "Playback time in minutes and seconds.")
    }

    static func compactPlaybackPosition(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
