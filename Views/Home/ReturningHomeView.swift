import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ReturningHomeView: View {
    @Binding var activeVideo: VideoItem?
    var totalStudyTime: TimeInterval
    var onOpenSettings: () -> Void

    @State private var showingAddSheet = false
    @State private var addDestination: AddDestination = .watchLater
    @Query(sort: \StudySession.startTime, order: .reverse) private var studySessions: [StudySession]
    @Query(sort: \VideoItem.createdAt, order: .reverse) private var videos: [VideoItem]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection
                actionCards
                recommendationsSection
                Spacer(minLength: 32)
            }
            .padding(.top, 48)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet(
                activeVideo: $activeVideo,
                onAddNow: addDestination == .startNow ? {} : nil
            )
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("こんにちは")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(TikTokTheme.primaryText)
                    Text("今日も一緒に学びましょう！")
                        .font(.subheadline)
                        .foregroundColor(TikTokTheme.secondaryText)
                }
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(TikTokTheme.secondaryText)
                        .padding(10)
                        .background(Circle().fill(TikTokTheme.panelStrong))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("設定")
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Spacer()

            // Bottom Cards
            HStack(alignment: .bottom, spacing: 12) {
                TodayStudyCard(minutes: todayMinutes, deltaMinutes: deltaMinutes)
                Spacer(minLength: 0)
                LevelCard(levelState: levelState, streakDays: streakDays)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 240)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(TikTokTheme.panelStrong)

                VStack {
                    Spacer()
                    Image(growthAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 168, height: 168)
                        .offset(x: 8, y: 10)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.smooth(duration: 0.35), value: growthAssetName)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(TikTokTheme.border, lineWidth: 1)
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
                accent: TikTokTheme.pink,
                background: TikTokTheme.panelStrong
            ) {
                addDestination = .startNow
                showingAddSheet = true
            }

            ActionCard(
                title: "後で見る",
                subtitle: "フォルダを選んで動画を保存",
                systemImage: "folder.fill",
                accent: TikTokTheme.readableBlue,
                background: TikTokTheme.panelStrong
            ) {
                addDestination = .watchLater
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
                    .foregroundColor(TikTokTheme.primaryText)
                Spacer()
                Button("すべて見る") {}
                    .font(.subheadline)
                    .foregroundColor(TikTokTheme.secondaryText)
                    .buttonStyle(.plain)
            }

            if recommendedVideos.isEmpty {
                VStack(spacing: 6) {
                    Text("おすすめ動画がまだありません")
                        .font(.subheadline)
                        .foregroundColor(TikTokTheme.secondaryText)
                    Text("動画を追加するとここに表示されます")
                        .font(.caption)
                        .foregroundColor(TikTokTheme.mutedText)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(TikTokTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(recommendedVideos.prefix(3)) { video in
                        RecommendationRow(video: video) {
                            activeVideo = video
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var recommendedVideos: [VideoItem] {
        let focusFolderID = recentFocusFolderID
        return videos.sorted {
            let lhsScore = StudyProgress.recommendationScore(for: $0, focusFolderID: focusFolderID)
            let rhsScore = StudyProgress.recommendationScore(for: $1, focusFolderID: focusFolderID)
            if lhsScore == rhsScore {
                return ($0.lastWatchedAt ?? $0.createdAt) > ($1.lastWatchedAt ?? $1.createdAt)
            }
            return lhsScore > rhsScore
        }
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

    private var streakDays: Int {
        let calendar = Calendar.current
        let activeDays = Set(
            studySessions
                .filter { $0.duration > 0 }
                .map { calendar.startOfDay(for: $0.startTime) }
        )
        guard !activeDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let startDay = activeDays.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var day = startDay
        var count = 0
        while activeDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previous
        }
        return count
    }

    private var levelState: StudyGrowth.LevelState {
        StudyGrowth.levelState(totalStudyTime: totalStudyTime, streakDays: streakDays)
    }

    private var growthAssetName: String {
        levelState.assetName
    }

    private var recentFocusFolderID: UUID? {
        videos
            .filter { $0.folder != nil && $0.lastWatchedAt != nil }
            .sorted { ($0.lastWatchedAt ?? .distantPast) > ($1.lastWatchedAt ?? .distantPast) }
            .first?
            .folder?
            .id
    }
}

private enum AddDestination {
    case startNow
    case watchLater
}

private struct TodayStudyCard: View {
    var minutes: Int
    var deltaMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(TikTokTheme.cyan)
                Text("今日の学習時間")
                    .font(.caption2)
                    .foregroundColor(TikTokTheme.secondaryText)
            }
            Text(primaryText)
                .font(.system(size: minutes == 0 ? 24 : 30, weight: .bold, design: .rounded))
                .foregroundColor(TikTokTheme.primaryText)
            Text(deltaText)
                .font(.caption2)
                .foregroundColor(deltaMinutes >= 0 ? TikTokTheme.green : TikTokTheme.secondaryText)
                .opacity(0.8)
        }
        .padding(14)
        .background(TikTokTheme.panelStrong)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var deltaText: String {
        guard minutes > 0 else {
            return "短く始めても大丈夫"
        }
        let sign = deltaMinutes >= 0 ? "+" : ""
        return "昨日より \(sign)\(deltaMinutes)分"
    }

    private var primaryText: String {
        minutes > 0 ? "\(minutes)分" : "まず1本"
    }
}

private struct LevelCard: View {
    var levelState: StudyGrowth.LevelState
    var streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundColor(TikTokTheme.green)
                Text("Lv. \(levelState.level)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TikTokTheme.primaryText)
            }
            ProgressView(value: levelState.progress)
                .tint(TikTokTheme.cyan)
                .frame(width: 72)
                .scaleEffect(x: 1, y: 0.8, anchor: .leading)
            Text("\(levelState.currentLevelXP)/\(levelState.requiredXP) XP")
                .font(.caption2.monospacedDigit())
                .foregroundColor(TikTokTheme.secondaryText)
            if streakDays > 0 {
                Text("\(streakDays)日連続")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(TikTokTheme.green)
            }
        }
        .padding(12)
        .background(TikTokTheme.panelStrong)
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
                    .foregroundColor(TikTokTheme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(TikTokTheme.secondaryText)
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
                    .stroke(TikTokTheme.border, lineWidth: 1)
            )
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
                        .foregroundColor(TikTokTheme.primaryText)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        SourceTag(text: sourceText)
                        if let folderName {
                            Text(folderName)
                                .font(.caption2)
                                .foregroundColor(TikTokTheme.mutedText)
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(TikTokTheme.cyan)
                        Text(playbackProgressText)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(TikTokTheme.mutedText)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(TikTokTheme.pink)
                    .clipShape(Circle())
            }
            .padding(12)
            .background(TikTokTheme.panelStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(TikTokTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var progress: Double {
        StudyProgress.progress(for: video)
    }

    private var playbackProgressText: String {
        StudyProgress.compactPlaybackPositionText(for: video)
    }

    private var lastPlaybackPosition: TimeInterval {
        StudyProgress.lastPlaybackPosition(for: video)
    }

    private var folderName: String? {
        if let name = video.folder?.name, !name.isEmpty {
            return name
        }
        return nil
    }

    private var sourceText: String {
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
        StudyProgress.statusText(for: video)
    }

    private var durationText: String? {
        StudyProgress.durationText(for: video)
    }
}

private struct SourceTag: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(TikTokTheme.secondaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(TikTokTheme.border.opacity(0.7))
            .clipShape(Capsule())
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
            colors: [TikTokTheme.panelStrong, TikTokTheme.cyan.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
