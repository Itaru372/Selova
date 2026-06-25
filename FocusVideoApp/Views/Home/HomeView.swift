import SwiftUI
import SwiftData

struct HomeView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @Binding var activeVideo: VideoItem?
    @Binding var isFocusInsightsPresented: Bool
    var onOpenSettings: () -> Void
    @State private var showingAddSheet = false

    @Query private var studySessions: [StudySession]

    var totalFocusedTime: TimeInterval {
        studySessions.reduce(0) { $0 + $1.focusedDuration }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TimeBasedBackgroundView()

                if !hasLaunchedBefore {
                    FirstTimeHomeView(
                        activeVideo: $activeVideo,
                        onOpenSettings: onOpenSettings,
                        onStart: {
                            hasLaunchedBefore = true
                        },
                        onShowAddVideo: {
                            showingAddSheet = true
                        }
                    )
                } else {
                    ReturningHomeView(
                        activeVideo: $activeVideo,
                        isFocusInsightsPresented: $isFocusInsightsPresented,
                        totalFocusedTime: totalFocusedTime,
                        onOpenSettings: onOpenSettings,
                        onShowAddVideo: {
                            showingAddSheet = true
                        }
                    )
                }
            }
            .navigationTitle("Home")
            .toolbarVisibility(.hidden, for: .navigationBar)
            .toolbar(isFocusInsightsPresented ? .hidden : .visible, for: .tabBar)
            .background(TikTokTheme.background)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet()
        }
        .onChange(of: showingAddSheet) { _, isPresented in
            if isPresented {
                SelovaAnalytics.track(.videoAdded, properties: ["stage": "started", "entry_point": "home"])
            }
        }
    }
}

struct FirstTimeHomeView: View {
    @Binding var activeVideo: VideoItem?
    var onOpenSettings: () -> Void
    var onStart: () -> Void
    var onShowAddVideo: () -> Void

    @State private var showingHelpSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                homeHeaderButtons
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Spacer(minLength: 24)

            VStack(spacing: 22) {
                FirstTimeFocusVisual()

                VStack(spacing: 10) {
                    Text("Selova")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(TikTokTheme.primaryText)
                        .minimumScaleFactor(0.82)

                    Text("フォルダで、集中して理解する。")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(TikTokTheme.secondaryText)
                }

                HStack(spacing: 8) {
                    FirstTimeSourcePill(title: "ローカル", systemImage: "folder.fill")
                    FirstTimeSourcePill(title: "YouTube", systemImage: "play.rectangle.fill")
                    FirstTimeSourcePill(title: "Vimeo", systemImage: "v.circle.fill")
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 34)

            HomeVideoCTAButton(
                title: "動画を追加する",
                subtitle: "フォルダに入れて、学習の流れを作ろう",
                systemImage: "plus.circle.fill",
                accent: TikTokTheme.pink
            ) {
                onStart()
                onShowAddVideo()
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 42)
        }
        .sheet(isPresented: $showingHelpSheet) {
            StudyXPHelpSheet()
        }
    }

    private var homeHeaderButtons: some View {
        HStack(spacing: 10) {
            Button(action: { showingHelpSheet = true }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(TikTokTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(TikTokTheme.panelStrong, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("XPのヘルプ")

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.headline)
                    .foregroundColor(TikTokTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(TikTokTheme.panelStrong, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定")
        }
    }
}

private struct FirstTimeFocusVisual: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(TikTokTheme.pink.opacity(colorScheme == .dark ? 0.18 : 0.12))
                .frame(width: 210, height: 210)
                .blur(radius: 36)
                .offset(x: -54, y: 18)

            Circle()
                .fill(TikTokTheme.readableBlue.opacity(colorScheme == .dark ? 0.22 : 0.14))
                .frame(width: 190, height: 190)
                .blur(radius: 34)
                .offset(x: 58, y: -28)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(TikTokTheme.panelStrong)
                .frame(width: 236, height: 256)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(TikTokTheme.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 24, x: 0, y: 18)

            VStack(spacing: 10) {
                MiniVideoPage(opacity: 0.54, scale: 0.82)
                    .offset(y: 3)

                MainVideoPage()

                MiniVideoPage(opacity: 0.34, scale: 0.82)
                    .offset(y: -3)
            }
            .frame(width: 190, height: 224)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == 1 ? TikTokTheme.pink : TikTokTheme.border)
                        .frame(width: index == 1 ? 18 : 7, height: 7)
                }
            }
            .padding(8)
            .background(TikTokTheme.panel.opacity(0.9), in: Capsule())
            .offset(x: 96, y: 2)
        }
        .frame(height: 282)
        .accessibilityHidden(true)
    }
}

private struct MainVideoPage: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        TikTokTheme.primaryText.opacity(0.92),
                        TikTokTheme.primaryText.opacity(0.74)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 176, height: 116)
            .overlay {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Image(systemName: "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .offset(x: 2)
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule()
                        .fill(TikTokTheme.pink)
                        .frame(width: 60, height: 5)
                    Capsule()
                        .fill(.white.opacity(0.34))
                        .frame(width: 118, height: 5)
                }
                .padding(16)
            }
    }
}

private struct MiniVideoPage: View {
    var opacity: Double
    var scale: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(TikTokTheme.primaryText.opacity(opacity))
            .frame(width: 168, height: 78)
            .scaleEffect(scale)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.72))
                    .offset(x: 1)
            }
    }
}

private struct FirstTimeSourcePill: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(TikTokTheme.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(TikTokTheme.panelStrong, in: Capsule())
        .overlay(
            Capsule()
                .stroke(TikTokTheme.border, lineWidth: 1)
        )
    }
}

#Preview("HomeView") {
    HomeViewPreviewHost()
}

private struct HomeViewPreviewHost: View {
    @State private var activeVideo: VideoItem?
    @State private var isFocusInsightsPresented = false

    private var previewContainer: ModelContainer {
        let schema = Schema([FolderItem.self, VideoItem.self, VideoNote.self, VideoAttentionEvent.self, StudySession.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    var body: some View {
        HomeView(
            activeVideo: $activeVideo,
            isFocusInsightsPresented: $isFocusInsightsPresented,
            onOpenSettings: {}
        )
        .modelContainer(previewContainer)
    }
}

struct StudyXPHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    helpCard(
                        title: "XP の基本",
                        icon: "sparkles",
                        content: [
                            "同じ動画をスクロールせずに見た 1分ごとに 10 XP",
                            "連続学習 1日ごとに 40 XP",
                            "動画を切り替えると、その区間の集中時間が確定します"
                        ]
                    )

                    helpCard(
                        title: "レベルアップ",
                        icon: "arrow.up.right.circle.fill",
                        content: [
                            "総 XP が増えると Lv. が上がります",
                            "必要 XP はレベルが上がるほど少しずつ増えます",
                            "ホームの XP 表示は、集中して見続けた時間で更新されます"
                        ]
                    )

                    helpCard(
                        title: "通知",
                        icon: "bell.badge.fill",
                        content: [
                            "離脱後の通知をオンにすると、動画モードを 10 秒以上見た後に閉じた場合だけ通知します",
                            "通知は「即時」「5分後」「10分後」の3段階です",
                            "設定画面で許可状態を確認・変更できます"
                        ]
                    )
                }
                .padding(20)
            }
            .background(TikTokTheme.background)
            .navigationTitle("ヘルプ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func helpCard(title: String, icon: String, content: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundColor(TikTokTheme.pink)
                    .frame(width: 34, height: 34)
                    .background(TikTokTheme.pink.opacity(0.12), in: Circle())
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(TikTokTheme.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(content, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(TikTokTheme.readableBlue)
                        Text(line)
                            .foregroundColor(TikTokTheme.secondaryText)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TikTokTheme.panelStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TikTokTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
