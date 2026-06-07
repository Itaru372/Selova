import SwiftUI
import SwiftData

struct HomeView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @Binding var activeVideo: VideoItem?
    var onOpenSettings: () -> Void

    @Query private var studySessions: [StudySession]

    var totalStudyTime: TimeInterval {
        studySessions.reduce(0) { $0 + $1.duration }
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
    @State private var addDestination: FirstTimeAddDestination = .startNow

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
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

            VStack(spacing: 14) {
                Button {
                    addDestination = .startNow
                    showingAddSheet = true
                } label: {
                    Text("今すぐ追加する")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(TikTokTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(TikTokTheme.pink)
                        )
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(TikTokTheme.cyan.opacity(0.22))
                                .frame(width: 7)
                        }
                        .shadow(color: TikTokTheme.pink.opacity(0.26), radius: 12, x: 0, y: 6)
                }

                Button {
                    addDestination = .watchLater
                    showingAddSheet = true
                } label: {
                    Text("後で見るフォルダに追加")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(TikTokTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(TikTokTheme.panelStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(TikTokTheme.border, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet(
                activeVideo: $activeVideo,
                onAddNow: addDestination == .startNow ? {
                    onStart()
                } : nil
            )
        }
    }
}

private enum FirstTimeAddDestination {
    case startNow
    case watchLater
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
