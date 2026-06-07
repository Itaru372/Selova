import SwiftUI
import SwiftData

struct HomeView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @Binding var activeVideo: VideoItem?
    var onOpenSettings: () -> Void

    @Query private var studySessions: [StudySession]
    @Query private var videos: [VideoItem]

    var totalStudyTime: TimeInterval {
        studySessions.reduce(0) { $0 + $1.duration }
    }

    var videoCompletionCount: Int {
        videos.reduce(0) { $0 + max(0, $1.completionCount ?? 0) }
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
                        }
                    )
                } else {
                    ReturningHomeView(
                        activeVideo: $activeVideo,
                        totalStudyTime: totalStudyTime,
                        videoCompletionCount: videoCompletionCount,
                        onOpenSettings: onOpenSettings
                    )
                }
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .background(TikTokTheme.background)
        }
    }
}

struct FirstTimeHomeView: View {
    @Binding var activeVideo: VideoItem?
    var onOpenSettings: () -> Void
    var onStart: () -> Void

    @State private var showingAddSheet = false
    @State private var showingHelpSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                homeHeaderButtons
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Spacer()

            VStack(spacing: 12) {
                Text("Focus Video")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(TikTokTheme.primaryText)

                Text("勉強を始めましょう")
                    .font(.headline)
                    .foregroundColor(TikTokTheme.secondaryText)
            }

            Spacer()

            HomeVideoCTAButton(
                title: "動画を追加する",
                subtitle: "今すぐ再生も、あとで保存もここから",
                systemImage: "plus.circle.fill",
                accent: TikTokTheme.pink
            ) {
                onStart()
                showingAddSheet = true
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet(activeVideo: $activeVideo)
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

#Preview("HomeView") {
    HomeViewPreviewHost()
}

private struct HomeViewPreviewHost: View {
    @State private var activeVideo: VideoItem?

    private var previewContainer: ModelContainer {
        let schema = Schema([FolderItem.self, VideoItem.self, StudySession.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    var body: some View {
        HomeView(
            activeVideo: $activeVideo,
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
                            "1分視聴ごとに 10 XP",
                            "連続学習 1日ごとに 40 XP",
                            "動画を最後まで見ると 1本ごとに 50 XP"
                        ]
                    )

                    helpCard(
                        title: "レベルアップ",
                        icon: "arrow.up.right.circle.fill",
                        content: [
                            "総 XP が増えると Lv. が上がります",
                            "必要 XP はレベルが上がるほど少しずつ増えます",
                            "ホームの XP 表示は、動画完了ボーナスも含めて更新されます"
                        ]
                    )

                    helpCard(
                        title: "通知",
                        icon: "bell.badge.fill",
                        content: [
                            "離脱後の通知をオンにすると、動画モードを 20 秒以上見た後に閉じた場合だけ通知します",
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
