import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var activeVideo: VideoItem?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(activeVideo: $activeVideo)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            LibraryView(activeVideo: $activeVideo)
                .tabItem {
                    Label("Library", systemImage: "folder")
                }
                .tag(1)
        }
        .fullScreenCover(item: $activeVideo) { video in
            StudyFeedView(video: video)
        }
    }
}

// Temporary wrapper to make VideoItem Identifiable for fullScreenCover if needed, 
// but VideoItem already has an `id: UUID`, so `item: $activeVideo` works if VideoItem is Identifiable.
// Actually @Model types conform to Identifiable.
