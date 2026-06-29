import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ReturningHomeView: View {
    @Binding var activeVideo: VideoItem?
    @Binding var isFocusInsightsPresented: Bool
    var totalFocusedTime: TimeInterval
    var onOpenSettings: () -> Void
    var onShowAddVideo: () -> Void

    @State private var showingAllRecommendations = false
    @State private var showingHelpSheet = false
    @Namespace private var focusInsightsNamespace
    @Query(sort: \StudySession.startTime, order: .reverse) private var studySessions: [StudySession]
    @Query(sort: \VideoItem.createdAt, order: .reverse) private var videos: [VideoItem]

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroSection
                    actionCards
                    recommendationsSection
                    Spacer(minLength: 32)
                }
                .padding(.top, 48)
            }
            .accessibilityHidden(isFocusInsightsPresented)

            if isFocusInsightsPresented {
                Color.black
                    .opacity(0.24)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)

                FocusInsightsSheet(
                    namespace: focusInsightsNamespace,
                    onDismiss: dismissFocusInsights
                )
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.985).combined(with: .opacity),
                        removal: .scale(scale: 0.985).combined(with: .opacity)
                    )
                )
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showingAllRecommendations) {
            RecommendationListSheet(videos: recommendedVideos) { video in
                trackRecommendationTap(
                    kind: "recommended_video",
                    surface: "recommendation_sheet",
                    video: video
                )
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

            Button {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    isFocusInsightsPresented = true
                }
            } label: {
                VStack(spacing: 6) {
                    Image(growthAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 176)
                        .frame(maxWidth: .infinity)
                        .matchedGeometryEffect(id: "growth-tree", in: focusInsightsNamespace)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.smooth(duration: 0.35), value: growthAssetName)

                    Label("集中の記録を見る", systemImage: "chart.xyaxis.line")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TikTokTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("集中の記録を見る")
            .accessibilityHint("直近7日間の集中時間と集中率を表示します")

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    GrowthMetricPill(
                        title: "今日の集中",
                        value: todayMinutes > 0
                            ? String(localized: "\(todayMinutes)分", comment: "Focused time today in minutes.")
                            : String(localized: "まず集中"),
                        systemImage: "clock.fill",
                        accent: TikTokTheme.green
                    )

                    GrowthMetricPill(
                        title: "連続",
                        value: streakDays > 0
                            ? String(localized: "\(streakDays)日", comment: "Current study streak in days.")
                            : String(localized: "今日から"),
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

    private func dismissFocusInsights() {
        withAnimation(.easeInOut(duration: 0.26)) {
            isFocusInsightsPresented = false
        }
    }

    private var actionCards: some View {
        HomeVideoCTAButton(
            title: "動画を追加する",
            subtitle: "フォルダに入れて、学習の流れを作ろう",
            systemImage: "plus.circle.fill",
            accent: TikTokTheme.pink
        ) {
            onShowAddVideo()
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

            if !attentionRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("もう一度集中したいところ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TikTokTheme.primaryText)

                    ForEach(attentionRecommendations.prefix(3)) { recommendation in
                        AttentionRecommendationRow(recommendation: recommendation) {
                            trackRecommendationTap(
                                kind: "attention_gap",
                                surface: "home",
                                video: recommendation.video
                            )
                            recommendation.video.requestedPlaybackTime = recommendation.startTime
                            activeVideo = recommendation.video
                        }
                    }
                }
            }

            if recommendedVideos.isEmpty && attentionRecommendations.isEmpty {
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
                            trackRecommendationTap(
                                kind: "recommended_video",
                                surface: "home",
                                video: video
                            )
                            activeVideo = video
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func trackRecommendationTap(kind: String, surface: String, video: VideoItem) {
        SelovaAnalytics.track(.recommendationTapped, properties: [
            "recommendation_kind": kind,
            "surface": surface,
            "video_source": video.typeRawValue
        ])
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

    private var attentionRecommendations: [StudyProgress.AttentionGap] {
        StudyProgress.attentionRecommendations(from: videos)
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
            .reduce(0) { $0 + $1.focusedDuration }
    }

    private var yesterdayStudyTime: TimeInterval {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return studySessions
            .filter { $0.startTime >= yesterdayStart && $0.startTime < todayStart }
            .reduce(0) { $0 + $1.focusedDuration }
    }

    private var streakDays: Int {
        let calendar = Calendar.current
        let activeDays = Set(
            studySessions
                .filter { $0.focusedDuration > 0 }
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
            totalFocusedTime: totalFocusedTime,
            streakDays: streakDays
        )
    }

    private var growthAssetName: String {
        levelState.assetName
    }

    private var primaryStudyText: String {
        todayMinutes > 0
            ? String(localized: "今日 \(todayMinutes)分 集中", comment: "Hero summary for today's focused minutes.")
            : String(localized: "最初の集中を始めよう")
    }

    private var deltaMessage: String {
        guard todayMinutes > 0 else {
            return String(localized: "同じ動画を見続けると、木が育ちます")
        }
        let sign = deltaMinutes >= 0 ? "+" : ""
        return String(localized: "昨日より \(sign)\(deltaMinutes)分", comment: "Difference from yesterday in minutes.")
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
    var title: LocalizedStringResource
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
    var title: LocalizedStringResource
    var subtitle: LocalizedStringResource
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
        StudyProgress.localizedCompactPlaybackPositionText(for: video)
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
            return String(localized: "ローカル")
        }
    }

    private var statusText: String {
        StudyProgress.localizedStatusText(for: video)
    }

    private var durationText: String? {
        StudyProgress.durationText(for: video)
    }
}

private struct AttentionRecommendationRow: View {
    let recommendation: StudyProgress.AttentionGap
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TikTokTheme.pink)
                    .frame(width: 42, height: 42)
                    .background(TikTokTheme.pink.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.video.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TikTokTheme.primaryText)
                        .lineLimit(1)
                    Text("スクロールが多かった区間: \(recommendation.rangeText)")
                        .font(.caption)
                        .foregroundStyle(TikTokTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(TikTokTheme.pink, in: Circle())
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
        .accessibilityLabel(
            Text(
                "\(recommendation.video.title)、集中し直す区間 \(recommendation.rangeText) から再生",
                comment: "Accessibility label for replaying a recommended attention gap. First value is the video title, second is the time range."
            )
        )
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
