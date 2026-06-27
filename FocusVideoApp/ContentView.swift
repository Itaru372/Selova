import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Query private var videos: [VideoItem]
    @State private var selectedTab = 0
    @State private var activeVideo: VideoItem?
    @State private var showingSettings = false
    @State private var showingFocusInsights = false
    @State private var didTrackInitialAppearance = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                activeVideo: $activeVideo,
                isFocusInsightsPresented: $showingFocusInsights
            ) {
                SelovaAnalytics.track(.settingChanged, properties: ["action": "settings_opened"])
                showingSettings = true
            }
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
        .tint(TikTokTheme.readableBlue)
        .toolbarBackground(Color.clear, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbar(showingFocusInsights ? .hidden : .visible, for: .tabBar)
        .onAppear {
            guard !didTrackInitialAppearance else { return }
            didTrackInitialAppearance = true
            SelovaAnalytics.track(.appLaunched)
            SelovaAnalytics.trackScreen("home")
            handlePendingResumeRequestIfNeeded()
        }
        .onChange(of: selectedTab) { _, tab in
            let screen = tab == 0 ? "home" : "library"
            SelovaAnalytics.track(.tabSelected, properties: ["tab_name": screen])
            SelovaAnalytics.trackScreen(screen)
        }
        .onReceive(NotificationCenter.default.publisher(for: SelovaResumeRoute.notificationName)) { _ in
            handlePendingResumeRequestIfNeeded()
        }
        .onOpenURL { url in
            guard let request = SelovaResumeRoute.request(from: url) else { return }
            handleResumeRequest(request)
        }
        .fullScreenCover(item: $activeVideo) { video in
            StudyFeedView(video: video)
        }
        .sheet(isPresented: $showingSettings) {
            StudySettingsView()
                .presentationDetents([.medium])
        }
    }

    private func handlePendingResumeRequestIfNeeded() {
        guard let request = SelovaResumeRoute.consumePendingRequest() else { return }
        handleResumeRequest(request)
    }

    private func handleResumeRequest(_ request: SelovaResumeRequest) {
        selectedTab = 0
        showingSettings = false
        showingFocusInsights = false

        let matchedVideo = request.videoID.flatMap { requestedID in
            videos.first(where: { $0.id == requestedID })
        }
        if let matchedVideo {
            activeVideo = matchedVideo
        }

        var properties: [String: Any] = ["source": request.source.rawValue]
        if let reminderID = request.reminderID {
            properties["reminder_id"] = reminderID
        }
        if let matchedVideo {
            properties["video_source"] = matchedVideo.typeRawValue
        }

        SelovaAnalytics.trackImmediately(.returnToStudy, properties: properties)
    }
}

enum TikTokTheme {
    static let background = adaptiveColor(
        light: UIColor(red: 0.965, green: 0.968, blue: 0.982, alpha: 1),
        dark: UIColor(red: 0.055, green: 0.060, blue: 0.078, alpha: 1)
    )
    static let elevatedBackground = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.92),
        dark: UIColor(red: 0.115, green: 0.120, blue: 0.145, alpha: 0.94)
    )
    static let panel = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.72),
        dark: UIColor(red: 0.135, green: 0.140, blue: 0.170, alpha: 0.74)
    )
    static let panelStrong = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.94),
        dark: UIColor(red: 0.130, green: 0.135, blue: 0.165, alpha: 0.96)
    )
    static let border = adaptiveColor(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.white.withAlphaComponent(0.12)
    )
    static let primaryText = adaptiveColor(
        light: UIColor.black.withAlphaComponent(0.92),
        dark: UIColor.white.withAlphaComponent(0.94)
    )
    static let secondaryText = adaptiveColor(
        light: UIColor.black.withAlphaComponent(0.66),
        dark: UIColor.white.withAlphaComponent(0.68)
    )
    static let mutedText = adaptiveColor(
        light: UIColor.black.withAlphaComponent(0.48),
        dark: UIColor.white.withAlphaComponent(0.46)
    )
    static let pink = Color(red: 1.0, green: 0.0, blue: 0.28)
    static let cyan = Color(red: 0.12, green: 0.92, blue: 1.0)
    static let readableBlue = adaptiveColor(
        light: UIColor(red: 0.0, green: 0.42, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.36, green: 0.68, blue: 1.0, alpha: 1)
    )
    static let actionBlue = adaptiveColor(
        light: UIColor(red: 0.15, green: 0.58, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.42, green: 0.72, blue: 1.0, alpha: 1)
    )
    static let green = adaptiveColor(
        light: UIColor(red: 0.0, green: 0.62, blue: 0.30, alpha: 1),
        dark: UIColor(red: 0.26, green: 0.94, blue: 0.56, alpha: 1)
    )

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

// Temporary wrapper to make VideoItem Identifiable for fullScreenCover if needed, 
// but VideoItem already has an `id: UUID`, so `item: $activeVideo` works if VideoItem is Identifiable.
// Actually @Model types conform to Identifiable.
