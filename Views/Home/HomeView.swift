import SwiftUI
import SwiftData

struct HomeView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    @Binding var activeVideo: VideoItem?
    
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
                    FirstTimeHomeView(activeVideo: $activeVideo, onStart: {
                        hasLaunchedBefore = true
                    })
                } else {
                    ReturningHomeView(activeVideo: $activeVideo, totalStudyTime: totalStudyTime)
                }
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .environment(\.colorScheme, .light)
        }
    }
}

struct FirstTimeHomeView: View {
    @Binding var activeVideo: VideoItem?
    var onStart: () -> Void
    
    @State private var showingAddSheet = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Focus Video")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            
            Text("勉強を始めましょう")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                showingAddSheet = true
            } label: {
                Text("今すぐ追加する")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 40)
            
            Button {
                showingAddSheet = true
            } label: {
                Text("後で見るフォルダに追加")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddVideoSheet(activeVideo: $activeVideo, onAddNow: {
                onStart()
            })
        }
    }
}
