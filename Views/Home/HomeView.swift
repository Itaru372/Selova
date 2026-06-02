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
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Text("Focus Video")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text("勉強を始めましょう")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 14) {
                Button {
                    showingAddSheet = true
                } label: {
                    Text("今すぐ追加する")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.blue)
                        )
                        .shadow(color: Color.blue.opacity(0.25), radius: 8, x: 0, y: 4)
                }

                Button {
                    showingAddSheet = true
                } label: {
                    Text("後で見るフォルダに追加")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }
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
