import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var activeVideo: VideoItem?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(activeVideo: $activeVideo)
                .tabItem {
                    Label("ホーム", systemImage: "house")
                }
                .tag(0)
            
            LibraryView(activeVideo: $activeVideo)
                .tabItem {
                    Label("ライブラリ", systemImage: "folder")
                }
                .tag(1)
        }
        .tint(TikTokTheme.cyan)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(item: $activeVideo) { video in
            StudyFeedView(video: video)
        }
    }
}

enum TikTokTheme {
    static let background = Color(red: 0.965, green: 0.968, blue: 0.982)
    static let elevatedBackground = Color.white.opacity(0.92)
    static let panel = Color.white.opacity(0.72)
    static let panelStrong = Color.white.opacity(0.94)
    static let border = Color.black.opacity(0.08)
    static let primaryText = Color.black.opacity(0.9)
    static let secondaryText = Color.black.opacity(0.58)
    static let mutedText = Color.black.opacity(0.38)
    static let pink = Color(red: 1.0, green: 0.0, blue: 0.28)
    static let cyan = Color(red: 0.12, green: 0.92, blue: 1.0)
    static let readableBlue = Color(red: 0.0, green: 0.42, blue: 0.95)
    static let actionBlue = Color(red: 0.15, green: 0.58, blue: 1.0)
    static let green = Color(red: 0.15, green: 0.95, blue: 0.55)
}

// Temporary wrapper to make VideoItem Identifiable for fullScreenCover if needed, 
// but VideoItem already has an `id: UUID`, so `item: $activeVideo` works if VideoItem is Identifiable.
// Actually @Model types conform to Identifiable.
