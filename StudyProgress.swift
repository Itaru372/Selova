import Foundation

enum StudyProgress {
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

    static func compactPlaybackPosition(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
