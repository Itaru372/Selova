import SwiftUI
import AVKit
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct StudyFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var video: VideoItem
    @State private var sharedPlayer: SharedVideoPlayer
    @State private var sessionStartTime = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var isPaging = false
    @State private var virtualPageIndex = 0
    
    init(video: VideoItem) {
        self.video = video
        _sharedPlayer = State(initialValue: SharedVideoPlayer(video: video))
    }
    
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let isPortrait = proxy.size.height >= proxy.size.width
            let isDragging = abs(dragOffset) > 1 || isPaging
            let cornerRadius = isDragging ? 28.0 : 0.0
            
            ZStack(alignment: .topLeading) {
                backgroundColor.ignoresSafeArea()
                pageShellStack(height: height)
                pageContent
                    .offset(y: dragOffset)
                    .scaleEffect(isDragging ? 0.98 : 1)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(isDragging ? 0.18 : 0), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isDragging ? 0.35 : 0), radius: isDragging ? 18 : 0, x: 0, y: 10)
                    .animation(.easeOut(duration: 0.18), value: isDragging)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        guard isPortrait, !isPaging else { return }
                        let vertical = value.translation.height
                        let horizontal = value.translation.width
                        guard abs(vertical) > abs(horizontal) else { return }
                        dragOffset = min(max(vertical, -height), height)
                    }
                    .onEnded { value in
                        guard isPortrait, !isPaging else {
                            dragOffset = 0
                            return
                        }
                        let vertical = value.translation.height
                        let horizontal = value.translation.width
                        guard abs(vertical) > abs(horizontal) else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                            return
                        }
                        let threshold = height * 0.25
                        if vertical <= -threshold {
                            handlePageSwipe(direction: .up, height: height)
                        } else if vertical >= threshold {
                            handlePageSwipe(direction: .down, height: height)
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear {
            sessionStartTime = Date()
            video.lastWatchedAt = Date()
        }
    }
    
    private var backgroundColor: Color {
        Color(red: 0.06, green: 0.08, blue: 0.12)
    }
    
    private func pageShellStack(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([-1, 0, 1], id: \.self) { index in
                pageShell(height: height)
                    .offset(y: CGFloat(index) * height)
            }
        }
        .offset(y: dragOffset)
    }
    
    private func pageShell(height: CGFloat) -> some View {
        ZStack {
            backgroundColor
#if canImport(UIKit)
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.22)
            }
#endif
            LinearGradient(
                colors: [Color.black.opacity(0.35), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: height)
        .clipped()
    }
    
#if canImport(UIKit)
    private var thumbnailImage: UIImage? {
        guard let data = video.thumbnailData else { return nil }
        return UIImage(data: data)
    }
#endif
    
    private var pageContent: some View {
        ZStack(alignment: .topLeading) {
            videoContent
                .ignoresSafeArea()
            
            // Simple Back Button
            Button(action: {
                finishSessionAndDismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.top, 50)
            .padding(.leading, 20)
        }
    }
    
    @ViewBuilder
    private var videoContent: some View {
        if let player = sharedPlayer.player {
            RealVideoPlayer(video: video, sharedPlayer: player)
        } else {
            RealVideoPlayer(video: video) { time in
                video.lastPlaybackTime = time
                try? modelContext.save()
            }
        }
    }
    
    private enum SwipeDirection {
        case up
        case down
    }
    
    private func handlePageSwipe(direction: SwipeDirection, height: CGFloat) {
        guard !isPaging else { return }
        isPaging = true
        let targetOffset = direction == .up ? -height : height
        let duration = 0.18
        withAnimation(.easeOut(duration: duration)) {
            dragOffset = targetOffset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragOffset = 0
            }
            virtualPageIndex += direction == .up ? 1 : -1
            isPaging = false
        }
    }
    
    private func finishSessionAndDismiss() {
        let duration = Date().timeIntervalSince(sessionStartTime)
        let session = StudySession(startTime: sessionStartTime, duration: duration)
        modelContext.insert(session)
        
        if let player = sharedPlayer.player {
            let currentTime = player.currentTime().seconds
            if !currentTime.isNaN {
                video.lastPlaybackTime = currentTime
            }
            sharedPlayer.stop()
        }
        
        video.watchedDuration += duration
        try? modelContext.save()
        
        dismiss()
    }
}

private final class SharedVideoPlayer {
    let player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    
    init(video: VideoItem) {
        guard video.type == .local else {
            player = nil
            return
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(video.urlString)
        let player = AVPlayer(url: fileURL)
        self.player = player
        
        if let lastTime = video.lastPlaybackTime {
            let cmTime = CMTime(seconds: lastTime, preferredTimescale: 600)
            player.seek(to: cmTime)
        }
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        player.play()
    }
    
    func stop() {
        player?.pause()
    }
    
    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}
