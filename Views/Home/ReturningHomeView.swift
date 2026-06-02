import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ReturningHomeView: View {
    @Binding var activeVideo: VideoItem?
    var totalStudyTime: TimeInterval

    @State private var showingAddSheet = false
    @Query(sort: \StudySession.startTime, order: .reverse) private var studySessions: [StudySession]
    @Query(sort: \VideoItem.lastWatchedAt, order: .reverse) private var recentVideos: [VideoItem]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection
                actionCards
                recommendationsSection
                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet(activeVideo: $activeVideo, onAddNow: nil)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("こんにちは")
                        .font(.title2.weight(.semibold))
                    Text("今日も一緒に学びましょう！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "tree.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(10)
                        .background(Circle().fill(.regularMaterial))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Spacer()

            // Bottom Cards
            HStack(alignment: .bottom, spacing: 12) {
                TodayStudyCard(minutes: todayMinutes, deltaMinutes: deltaMinutes)
                Spacer(minLength: 0)
                LevelCard(level: level, progress: levelProgress)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 240)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)

                VStack {
                    Spacer()
                    Image(systemName: "tree.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.5), Color.green.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(x: 10, y: 15)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    private var actionCards: some View {
        HStack(spacing: 14) {
            ActionCard(
                title: "今すぐ学習する",
                subtitle: "動画を追加して学習を始めましょう",
                systemImage: "play.fill",
                accent: Color(red: 0.25, green: 0.6, blue: 0.35),
                background: Color(red: 0.92, green: 0.97, blue: 0.92)
            ) {
                showingAddSheet = true
            }

            ActionCard(
                title: "後で見る",
                subtitle: "フォルダを選んで動画を保存",
                systemImage: "folder.fill",
                accent: Color(red: 0.4, green: 0.45, blue: 0.85),
                background: Color(red: 0.93, green: 0.93, blue: 0.98)
            ) {
                showingAddSheet = true
            }
        }
        .padding(.horizontal, 20)
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("おすすめ")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("すべて見る") {}
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
            }

            if recentVideos.isEmpty {
                VStack(spacing: 6) {
                    Text("おすすめ動画がまだありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("動画を追加するとここに表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(recentVideos.prefix(3)) { video in
                        RecommendationRow(video: video) {
                            activeVideo = video
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var todayMinutes: Int {
        max(0, Int(todayStudyTime / 60))
    }

    private var deltaMinutes: Int {
        Int((todayStudyTime - yesterdayStudyTime) / 60)
    }

    private var todayStudyTime: TimeInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        return studySessions
            .filter { $0.startTime >= start && $0.startTime < end }
            .reduce(0) { $0 + $1.duration }
    }

    private var yesterdayStudyTime: TimeInterval {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return studySessions
            .filter { $0.startTime >= yesterdayStart && $0.startTime < todayStart }
            .reduce(0) { $0 + $1.duration }
    }

    private var level: Int {
        let levelUnit: TimeInterval = 3600
        return max(1, Int(totalStudyTime / levelUnit) + 1)
    }

    private var levelProgress: Double {
        let levelUnit: TimeInterval = 3600
        let remainder = totalStudyTime.truncatingRemainder(dividingBy: levelUnit)
        return min(max(remainder / levelUnit, 0), 1)
    }
}

private struct TodayStudyCard: View {
    var minutes: Int
    var deltaMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("今日の学習時間")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text("\(minutes)分")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(deltaText)
                .font(.caption2)
                .foregroundColor(deltaMinutes >= 0 ? .green : .secondary)
                .opacity(0.8)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var deltaText: String {
        let sign = deltaMinutes >= 0 ? "+" : ""
        return "昨日より \(sign)\(deltaMinutes)分"
    }
}

private struct LevelCard: View {
    var level: Int
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("Lv. \(level)")
                    .font(.caption.weight(.semibold))
            }
            ProgressView(value: progress)
                .tint(.green)
                .frame(width: 72)
                .scaleEffect(x: 1, y: 0.8, anchor: .leading)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ActionCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var accent: Color
    var background: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: systemImage)
                            .font(.subheadline)
                            .foregroundColor(accent)
                    }
                    Spacer()
                }
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(accent.opacity(0.6))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct RecommendationRow: View {
    var video: VideoItem
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                VideoThumbnail(
                    data: video.thumbnailData,
                    statusText: statusText,
                    durationText: durationText
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(video.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(categoryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(Color(red: 0.35, green: 0.7, blue: 0.3))
                        Text(playbackProgressText)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(9)
                    .background(Color.green)
                    .clipShape(Circle())
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var progress: Double {
        guard video.duration > 0 else { return 0 }
        return min(max(video.watchedDuration / video.duration, 0), 1)
    }

    private var playbackProgressText: String {
        guard video.duration > 0 else { return "再生中" }
        let watchedMins = Int(video.watchedDuration / 60)
        let totalMins = Int(video.duration / 60)
        return "\(watchedMins)分 / \(totalMins)分"
    }

    private var categoryText: String {
        if let name = video.folder?.name, !name.isEmpty {
            return name
        }
        switch video.type {
        case .youtube:
            return "YouTube"
        case .vimeo:
            return "Vimeo"
        case .local:
            return "ローカル"
        }
    }

    private var statusText: String {
        if progress >= 0.9 {
            return "あと少し"
        }
        if video.watchedDuration > 0 {
            return "続きから"
        }
        return "未視聴"
    }

    private var durationText: String? {
        guard video.duration > 0 else { return nil }
        return formatDuration(video.duration)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct VideoThumbnail: View {
    var data: Data?
    var statusText: String
    var durationText: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            thumbnailImage
            if let durationText {
                Text(durationText)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(5)
            }
            VStack {
                HStack {
                    Text(statusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(5)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: 110, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var thumbnailImage: some View {
#if canImport(UIKit)
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
#else
        placeholder
#endif
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
