import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ReturningHomeView: View {
    @Binding var activeVideo: VideoItem?
    var totalStudyTime: TimeInterval
    var videoCompletionCount: Int
    var onOpenSettings: () -> Void

    @State private var showingAddSheet = false
    @State private var showingAllRecommendations = false
    @State private var showingHelpSheet = false
    @Query(sort: \StudySession.startTime, order: .reverse) private var studySessions: [StudySession]
    @Query(sort: \VideoItem.createdAt, order: .reverse) private var videos: [VideoItem]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                heroSection
                actionCards
                recommendationsSection
                Spacer(minLength: 32)
            }
            .padding(.top, 48)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet(activeVideo: $activeVideo)
        }
        .sheet(isPresented: $showingAllRecommendations) {
            RecommendationListSheet(videos: recommendedVideos) { video in
                showingAllRecommendations = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    activeVideo = video
                }
            }
        }
        .sheet(isPresented: $showingHelpSheet) {
            StudyXPHelpSheet()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(primaryStudyText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(TikTokTheme.primaryText)
                        .minimumScaleFactor(0.8)
                    Text(deltaMessage)
                        .font(.callout.weight(.medium))
                        .foregroundColor(TikTokTheme.secondaryText)
                }
                Spacer()
                headerButtons
            }

            Image(growthAssetName)
                .resizable()
                .scaledToFit()
                .frame(height: 176)
                .frame(maxWidth: .infinity)
                .transition(.scale.combined(with: .opacity))
                .animation(.smooth(duration: 0.35), value: growthAssetName)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    GrowthMetricPill(
                        title: "今日",
                        value: todayMinutes > 0 ? "\(todayMinutes)分" : "まず1本",
                        systemImage: "clock.fill",
                        accent: TikTokTheme.green
                    )

                    GrowthMetricPill(
                        title: "連続",
                        value: streakDays > 0 ? "\(streakDays)日" : "今日から",
                        systemImage: "flame.fill",
                        accent: TikTokTheme.green
                    )
                }

                LevelProgressStrip(levelState: levelState)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(TikTokTheme.panelStrong)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(TikTokTheme.green.opacity(0.12))
                        .frame(width: 160, height: 160)
                        .blur(radius: 28)
                        .offset(x: 46, y: -54)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(TikTokTheme.border, lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }

    private var actionCards: some View {
        HomeVideoCTAButton(
            title: "動画を追加する",
            subtitle: "今すぐ再生も、あとで保存もここから",
            systemImage: "plus.circle.fill",
            accent: TikTokTheme.pink
        ) {
            showingAddSheet = true
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
                Button("すべて見る") {
                    showingAllRecommendations = true
                }
                    .font(.subheadline)
                    .foregroundColor(TikTokTheme.secondaryText)
                    .buttonStyle(.plain)
                    .disabled(recommendedVideos.isEmpty)
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
        StudyGrowth.levelState(
            totalStudyTime: totalStudyTime,
            streakDays: streakDays,
            videoCompletionCount: videoCompletionCount
        )
    }

    private var growthAssetName: String {
        levelState.assetName
    }

    private var primaryStudyText: String {
        todayMinutes > 0 ? "今日 \(todayMinutes)分" : "今日の1本を始めよう"
    }

    private var deltaMessage: String {
        guard todayMinutes > 0 else {
            return "短くても、まず再生すれば木が育ちます"
        }
        let sign = deltaMinutes >= 0 ? "+" : ""
        return "昨日より \(sign)\(deltaMinutes)分"
    }

    private var recentFocusFolderID: UUID? {
        videos
            .filter { $0.folder != nil && $0.lastWatchedAt != nil }
            .sorted { ($0.lastWatchedAt ?? .distantPast) > ($1.lastWatchedAt ?? .distantPast) }
            .first?
            .folder?
            .id
    }

    private var headerButtons: some View {
        HStack(spacing: 10) {
            Button(action: { showingHelpSheet = true }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TikTokTheme.secondaryText)
                    .padding(10)
                    .background(Circle().fill(TikTokTheme.panelStrong))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("XPのヘルプ")

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
    }
}

private struct GrowthMetricPill: View {
    var title: String
    var value: String
    var systemImage: String
    var accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundColor(accent)
                .frame(width: 24, height: 24)
                .background(accent.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(TikTokTheme.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TikTokTheme.primaryText)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(TikTokTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LevelProgressStrip: View {
    var levelState: StudyGrowth.LevelState

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text("Lv. \(levelState.level)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(TikTokTheme.primaryText)
                Spacer()
                Text("\(levelState.currentLevelXP)/\(levelState.requiredXP) XP")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundColor(TikTokTheme.secondaryText)
            }

            ProgressView(value: levelState.progress)
                .tint(TikTokTheme.green)
                .scaleEffect(x: 1, y: 0.8, anchor: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(TikTokTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct HomeVideoCTAButton: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundColor(accent)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.95), in: Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.82))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.78))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: accent.opacity(0.18), radius: 14, x: 0, y: 8)
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

private struct RecommendationListSheet: View {
    @Environment(\.dismiss) private var dismiss

    var videos: [VideoItem]
    var onPlay: (VideoItem) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(videos) { video in
                        RecommendationRow(video: video) {
                            onPlay(video)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(TikTokTheme.background)
            .navigationTitle("おすすめ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .tint(TikTokTheme.readableBlue)
        }
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
