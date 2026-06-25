import SwiftUI
import AVKit
import WebKit
import SwiftData
import UserNotifications
import ObjectiveC.runtime
#if canImport(UIKit)
import UIKit
#endif

enum FeedPagingDirection {
    case up
    case down
}

struct StudyFeedView: View {
    let initialVideo: VideoItem

    @Query(sort: \VideoItem.createdAt) private var allVideos: [VideoItem]
    @State private var currentVideoID: UUID

    init(video: VideoItem) {
        self.initialVideo = video
        _currentVideoID = State(initialValue: video.id)
    }

    var body: some View {
        StudyFeedPageView(
            video: currentVideo,
            onFolderPage: advanceInFolder
        )
        .id(currentVideo.id)
    }

    private var currentVideo: VideoItem {
        allVideos.first(where: { $0.id == currentVideoID }) ?? initialVideo
    }

    private var folderVideosToContinue: [VideoItem] {
        guard let folderID = currentVideo.folder?.id else { return [currentVideo] }
        let candidates = allVideos.filter {
            $0.folder?.id == folderID && !StudyProgress.isCompleted($0)
        }
        return candidates.isEmpty ? [currentVideo] : candidates
    }

    private func advanceInFolder(_ direction: FeedPagingDirection) -> Bool {
        let candidates = folderVideosToContinue
        guard candidates.count > 1,
              let index = candidates.firstIndex(where: { $0.id == currentVideo.id }) else {
            return false
        }

        let offset = direction == .up ? 1 : -1
        let nextIndex = (index + offset + candidates.count) % candidates.count
        currentVideoID = candidates[nextIndex].id
        return true
    }
}

struct StudyFeedPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    var video: VideoItem
    var onFolderPage: ((FeedPagingDirection) -> Bool)?
    @State private var sessionStartTime = Date()
    @State private var sessionPlaybackStartTime: TimeInterval = 0
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var itemStatusObserver: NSKeyValueObservation?
    @State private var playbackError: String?
    @State private var swipeOffset: CGFloat = 0
    @State private var virtualPage = 0
    @State private var isPaging = false
    @State private var isDismissing = false
    @State private var didScheduleCloseReminders = false
    @State private var didStartResumeLiveActivity = false
    @State private var showingCompletionScreen = false
    @State private var webPlayerReloadID = UUID()
    @State private var webPlaybackStartTime: Double?
    @State private var shouldStopWebPlayback = false
    @State private var webPauseToken = UUID()
    @State private var showingNotes = false
    @State private var lastWebProgressSaveTime = Date.distantPast
    @State private var lastPersistedWebPlaybackSecond = -1
    @State private var lastPersistedWebDuration: Double?
    
    init(
        video: VideoItem,
        onFolderPage: ((FeedPagingDirection) -> Bool)? = nil
    ) {
        self.video = video
        self.onFolderPage = onFolderPage
        if video.type == .local {
            _player = State(initialValue: Self.makeLocalPlayer(for: video))
        } else {
            _player = State(initialValue: nil)
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                studyFeedBackground.ignoresSafeArea()
                videoPage(in: proxy.size)
                if showingCompletionScreen {
                    completionScreen
                        .padding(.horizontal, proxy.size.width > proxy.size.height ? 64 : 24)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .zIndex(4)
                }
            }
            .scaleEffect(isDismissing ? 0.965 : 1.0)
            .offset(y: isDismissing ? proxy.size.height * 0.045 : 0)
            .opacity(isDismissing ? 0.0 : 1.0)
            .allowsHitTesting(!isDismissing)
            .contentShape(Rectangle())
            .simultaneousGesture(feedSwipeGesture(in: proxy.size))
            .toolbar(.hidden, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
            .statusBarHidden(true)
            .onAppear {
                enableStudyFeedOrientation()
                sessionStartTime = Date()
                sessionPlaybackStartTime = currentPlaybackTime ?? 0
                video.lastWatchedAt = Date()
                SelovaAnalytics.trackScreen("study_feed")
                SelovaAnalytics.track(.videoStarted, properties: [
                    "video_source": video.typeRawValue,
                    "is_resumed": (video.lastPlaybackTime ?? 0) > 0
                ])
                setupPlayer()
                requestStudyReminderAuthorization()
            }
            .onDisappear {
                stopPlayer()
                restorePortraitOrientation()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
#if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                scheduleCloseReminderNotificationsIfNeeded()
            }
#endif
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func videoPage(in size: CGSize) -> some View {
        if showingNotes && size.width < size.height {
            portraitNotesVideoPage(in: size)
        } else if video.type == .local {
            if size.width > size.height {
                landscapeVideoPage(in: size)
            } else {
                portraitVideoPage(in: size)
            }
        } else {
            if size.width > size.height {
                webLandscapeVideoPage(in: size)
            } else {
                webPortraitVideoPage(in: size)
            }
        }
    }

    private func portraitNotesVideoPage(in size: CGSize) -> some View {
        let topHeight = size.height * 0.48

        return ZStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    playerContainer(gravity: .resizeAspect)
                }
                .frame(width: size.width, height: topHeight)
                .clipped()
                .overlay(
                    backButton
                        .zIndex(3),
                    alignment: .topLeading
                )

                notesSplitPanel(
                    in: size,
                    topHeight: topHeight
                )
            }

            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
                    .zIndex(4)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func notesSplitPanel(in size: CGSize, topHeight: CGFloat) -> some View {
        let bottomHeight = max(size.height - topHeight, 0)

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("メモ")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(TikTokTheme.primaryText)
                    Text("動画を止めずに、位置だけ残せます")
                        .font(.caption)
                        .foregroundStyle(TikTokTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        showingNotes = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TikTokTheme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(TikTokTheme.panelStrong, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()
                .overlay(TikTokTheme.border)

            VideoNotesEditor(
                video: video,
                currentTime: currentPlaybackTime,
                isInStudyMode: true,
                onJump: seekToTimestamp
            )
        }
        .frame(width: size.width, height: bottomHeight)
        .background(TikTokTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(TikTokTheme.border.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: -4)
    }

    private func webLandscapeVideoPage(in size: CGSize) -> some View {
        ZStack {
            feedPageSurface(in: size) {
                playerContainer(gravity: .resizeAspect)
            }
            .frame(width: size.width, height: size.height)
            
            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
                    .zIndex(2)
            }
            
            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(3)
            
            noteButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(3)
        }
        .frame(width: size.width, height: size.height)
        .sheet(isPresented: $showingNotes) {
            notesSheet
        }
    }
    
    private func webPortraitVideoPage(in size: CGSize) -> some View {
        ZStack {
            feedPageSurface(in: size) {
                thumbnailPage(in: size)
            }
            .frame(width: size.width, height: size.height)
            .offset(y: -size.height + swipeOffset)
            
            feedPageSurface(in: size) {
                thumbnailPage(in: size)
            }
            .frame(width: size.width, height: size.height)
            .offset(y: size.height + swipeOffset)
            
            feedPageSurface(in: size) {
                playerContainer(gravity: .resizeAspect)
            }
            .frame(width: size.width, height: size.height)
            .offset(y: swipeOffset)
            .zIndex(1)
            
            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
                    .zIndex(2)
            }
            
            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(3)
            
            noteButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(3)
        }
        .frame(width: size.width, height: size.height)
        .sheet(isPresented: $showingNotes) {
            notesSheet
        }
    }
    
    private func landscapeVideoPage(in size: CGSize) -> some View {
        ZStack {
            playerContainer(gravity: .resizeAspect)
                .frame(width: size.width, height: size.height)
                .background(Color.black)
                .clipped()
            
            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
                    .zIndex(2)
            }
            
            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(3)
            
            noteButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(3)
        }
        .frame(width: size.width, height: size.height)
        .sheet(isPresented: $showingNotes) {
            notesSheet
        }
    }
    
    private func portraitVideoPage(in size: CGSize) -> some View {
        ZStack {
            feedPageSurface(in: size) {
                thumbnailPage(in: size)
            }
            .frame(width: size.width, height: size.height)
            .offset(y: -size.height + swipeOffset)
            
            feedPageSurface(in: size) {
                thumbnailPage(in: size)
            }
            .frame(width: size.width, height: size.height)
            .offset(y: size.height + swipeOffset)
            
            feedPageSurface(in: size) {
                playerContainer(gravity: .resizeAspect)
            }
            .frame(width: size.width, height: size.height)
            .offset(y: swipeOffset)
            .zIndex(1)
            
            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
                    .zIndex(2)
            }
            
            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(3)
            
            noteButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(3)
        }
        .frame(width: size.width, height: size.height)
    }
    
    private var studyFeedBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.075),
                    Color(red: 0.075, green: 0.09, blue: 0.13),
                    Color(red: 0.035, green: 0.04, blue: 0.058)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            LinearGradient(
                colors: [
                    TikTokTheme.pink.opacity(0.22),
                    .clear,
                    TikTokTheme.readableBlue.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)
        }
    }
    
    private func feedPageSurface<Content: View>(
        in size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let horizontalInset: CGFloat = size.width > 430 ? 16 : 8
        let verticalInset: CGFloat = size.height > 700 ? 12 : 8
        let cornerRadius = feedSurfaceCornerRadius(for: size)
        let innerCornerRadius = max(cornerRadius - 4, cornerRadius * 0.9)
        
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.82))
            
            content()
                .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            TikTokTheme.readableBlue.opacity(0.38),
                            TikTokTheme.pink.opacity(0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, verticalInset)
        )
        .shadow(color: Color.black.opacity(0.36), radius: 24, x: 0, y: 14)
    }
    
    private func feedSurfaceCornerRadius(for size: CGSize) -> CGFloat {
        let minSide = min(size.width, size.height)
        return max(36, minSide * 0.12)
    }
    
    private func feedSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 28)
            .onChanged { value in
                guard !showingNotes else { return }
                guard !showingCompletionScreen else { return }
                guard size.height >= size.width else { return }
                guard !isPaging else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                swipeOffset = clamped(value.translation.height, min: -size.height, max: size.height)
            }
            .onEnded { value in
                guard !showingNotes else { return }
                guard !showingCompletionScreen else { return }
                guard size.height >= size.width else { return }
                guard !isPaging else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    withAnimation(.smooth(duration: 0.2)) {
                        swipeOffset = 0
                    }
                    return
                }
                
                let threshold = size.height * 0.22
                let predictedThreshold = size.height * 0.36
                let shouldPageUp = value.translation.height <= -threshold || value.predictedEndTranslation.height <= -predictedThreshold
                let shouldPageDown = value.translation.height >= threshold || value.predictedEndTranslation.height >= predictedThreshold
                
                if shouldPageUp {
                    finishVirtualPageSwipe(.up, height: size.height)
                } else if shouldPageDown {
                    finishVirtualPageSwipe(.down, height: size.height)
                } else {
                    withAnimation(.smooth(duration: 0.22)) {
                        swipeOffset = 0
                    }
                }
            }
    }
    
    private func finishVirtualPageSwipe(_ direction: FeedPagingDirection, height: CGFloat) {
        isPaging = true
        let targetOffset = direction == .up ? -height : height
        
        withAnimation(.smooth(duration: 0.24)) {
            swipeOffset = targetOffset
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                virtualPage += direction == .up ? 1 : -1
                swipeOffset = 0
            }

            guard onFolderPage?(direction) == true else {
                isPaging = false
                player?.play()
                return
            }

            SelovaAnalytics.track(.feedPaged, properties: [
                "direction": direction == .up ? "next" : "previous",
                "video_source": video.typeRawValue
            ])
            recordScrollAwayEvent()
            persistCurrentPlaybackPosition()
            isPaging = false
        }
    }
    
    private func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
    
    private func thumbnailPage(in size: CGSize) -> some View {
        ZStack {
            Color(red: 0.025, green: 0.03, blue: 0.045)
            
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width - 32, height: size.height - 32)
                    .clipped()
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.34))
            }
            
            LinearGradient(
                colors: [
                    .black.opacity(0.18),
                    .clear,
                    .black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .background(Color(red: 0.025, green: 0.03, blue: 0.045))
        .clipped()
    }
    
    private var thumbnailImage: UIImage? {
        guard let data = video.thumbnailData else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Player
    
    private func playerContainer(gravity: AVLayerVideoGravity) -> some View {
        Group {
            if video.type == .local {
                localPlayerView(gravity: gravity)
            } else if let descriptor = webPlayerDescriptor {
                webPlayerView(descriptor: descriptor)
            } else {
                playbackErrorView("動画URLを読み込めません")
            }
        }
        .background(Color.black)
    }
    
    private func localPlayerView(gravity: AVLayerVideoGravity) -> some View {
        LocalAVPlayerControllerView(
            player: player,
            videoGravity: gravity,
            autoPlay: true
        )
        .onAppear {
            setupPlayer()
        }
    }
    
    private func webPlayerView(descriptor: WebPlayerDescriptor) -> some View {
        WebViewPlayerFixed(
            descriptor: descriptor,
            startTime: webPlaybackStartTime ?? Self.validPlaybackTime(video.lastPlaybackTime) ?? 0,
            reloadID: webPlayerReloadID,
            isStopped: shouldStopWebPlayback,
            pauseToken: webPauseToken,
            onProgress: updateWebPlaybackProgress,
            onComplete: completePlayback,
            onError: { message in
                playbackError = message
            }
        )
        .onAppear {
            playbackError = nil
            if webPlaybackStartTime == nil {
                webPlaybackStartTime = Self.validPlaybackTime(video.requestedPlaybackTime)
                ?? Self.validPlaybackTime(video.lastPlaybackTime)
                ?? 0
                video.requestedPlaybackTime = nil
            }
        }
        .background(Color.black)
    }
    
    private func setupPlayer() {
        guard video.type == .local else { return }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(video.urlString)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            playbackError = "ローカル動画ファイルが見つかりません"
            return
        }
        
        playbackError = nil
        let activePlayer: AVPlayer
        if let player {
            activePlayer = player
        } else {
            let newPlayer = AVPlayer(url: fileURL)
            player = newPlayer
            activePlayer = newPlayer
        }
        
        if let lastTime = Self.validPlaybackTime(video.requestedPlaybackTime) ?? Self.validPlaybackTime(video.lastPlaybackTime) {
            let cmTime = CMTime(seconds: lastTime, preferredTimescale: 600)
            activePlayer.seek(to: cmTime)
            video.requestedPlaybackTime = nil
        }
        
        observePlaybackStatus(for: activePlayer)
        
        if endObserver == nil {
            let observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: activePlayer.currentItem,
                queue: .main
            ) { _ in
                completePlayback()
            }
            endObserver = observer
        }
        activePlayer.play()
    }
    
    private func observePlaybackStatus(for player: AVPlayer) {
        itemStatusObserver?.invalidate()
        itemStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) { item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    playbackError = nil
                    if player.rate == 0 && !showingCompletionScreen {
                        player.play()
                    }
                case .failed:
                    playbackError = playbackFailureMessage(for: item)
                    video.lastPlaybackTime = nil
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func playbackFailureMessage(for item: AVPlayerItem) -> String {
        guard let error = item.error as NSError? else {
            return "ローカル動画を再生できません"
        }
        
        var details = [
            error.localizedDescription,
            "\(error.domain) \(error.code)"
        ]
        
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            details.append("\(underlyingError.domain) \(underlyingError.code)")
        }
        
        if let event = item.errorLog()?.events.last {
            let status = event.errorStatusCode
            let comment = event.errorComment ?? event.errorDomain
            if status != 0 || !comment.isEmpty {
                details.append("\(comment) \(status)")
            }
        }
        
        return details.joined(separator: "\n")
    }
    
    private func stopPlayer() {
        if let player {
            if let currentTime = Self.validPlaybackTime(player.currentTime().seconds) {
                video.lastPlaybackTime = currentTime
            }
            player.pause()
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        itemStatusObserver?.invalidate()
        player = nil
        endObserver = nil
        itemStatusObserver = nil
    }
    
    // MARK: - Common
    
    private var backButton: some View {
        FrictionBackButton(
            onDismiss: finishSessionAndDismiss,
            allowsImmediateDismiss: showingCompletionScreen
        )
        .padding(.leading, 20)
        .padding(.top, 54)
    }
    
    private var noteButton: some View {
        Button {
            SelovaAnalytics.track(.notesOpened, properties: ["video_source": video.typeRawValue])
            withAnimation(.smooth(duration: 0.2)) {
                showingNotes = true
                swipeOffset = 0
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "note.text.badge.plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.34), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                
                if noteCount > 0 {
                    Text("\(min(noteCount, 99))")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TikTokTheme.pink, in: Capsule())
                        .offset(x: 4, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 54)
        .accessibilityLabel("メモ")
    }
    
    private var completionScreen: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(TikTokTheme.green.opacity(0.18))
                    .frame(width: 76, height: 76)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(TikTokTheme.green)
            }
            
            VStack(spacing: 6) {
                Text("この動画は完了です")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(video.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            Text("次の動画へ進むか、もう一度見て理解を深めよう")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            
            VStack(spacing: 10) {
                Button {
                    continueToNextVideo()
                } label: {
                    Label("次の動画へ", systemImage: "arrow.down.circle.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(TikTokTheme.pink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    replayVideo()
                } label: {
                    Label("もう一度見る", systemImage: "arrow.counterclockwise")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.9))
                .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Button {
                    finishSessionAndDismiss()
                } label: {
                    Text("ホームへ戻る")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.88))
                .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(24)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.38), radius: 28, x: 0, y: 18)
    }
    
    private var webPlayerDescriptor: WebPlayerDescriptor? {
        switch video.type {
        case .youtube:
            guard let id = VideoEmbedURLBuilder.youtubeVideoID(from: video.urlString) else { return nil }
            return WebPlayerDescriptor(provider: .youtube, videoID: id, sourceURLString: nil)
        case .vimeo:
            guard let id = VideoEmbedURLBuilder.vimeoVideoID(from: video.urlString),
                  let url = VideoEmbedURLBuilder.vimeoEmbedURL(from: video.urlString) else { return nil }
            return WebPlayerDescriptor(provider: .vimeo, videoID: id, sourceURLString: url.absoluteString)
        case .local:
            return nil
        }
    }
    
    private var noteCount: Int {
        video.notes?.count ?? 0
    }
    
    private var currentPlaybackTime: TimeInterval? {
        if let player,
           let currentTime = Self.validPlaybackTime(player.currentTime().seconds) {
            return currentTime
        }
        return Self.validPlaybackTime(video.lastPlaybackTime) ?? webPlaybackStartTime
    }
    
    private func seekToTimestamp(_ timestamp: TimeInterval) {
        let safeTimestamp = max(0, timestamp)
        shouldStopWebPlayback = false
        
        if video.type == .local {
            let cmTime = CMTime(seconds: safeTimestamp, preferredTimescale: 600)
            player?.seek(to: cmTime) { _ in
                player?.play()
            }
        } else {
            webPlaybackStartTime = safeTimestamp
            webPlayerReloadID = UUID()
        }
    }
    
    private func finishSessionAndDismiss() {
        guard !isDismissing else { return }
        cancelCloseReminderNotifications()
        StudyResumeActivityManager.endAll()
        
        let duration = recordFocusedSegment()
        
        player?.pause()
        shouldStopWebPlayback = true
        persistCurrentPlaybackPosition()
        video.watchedDuration += duration
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            playbackError = "学習記録を保存できませんでした"
            print("Failed to save study session: \(error)")
            return
        }
        
        withAnimation(.smooth(duration: 0.22)) {
            isDismissing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dismiss()
        }
    }
    
    private func completePlayback() {
        guard !showingCompletionScreen else { return }
        StudyResumeActivityManager.endAll()
        if video.duration > 0 {
            video.lastPlaybackTime = video.duration
        }
        video.completionCount = (video.completionCount ?? 0) + 1
        video.lastWatchedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            playbackError = "完了状態を保存できませんでした"
            print("Failed to save playback completion: \(error)")
            return
        }
        SelovaAnalytics.track(.videoCompleted, properties: ["video_source": video.typeRawValue])
        player?.pause()
        withAnimation(.smooth(duration: 0.24)) {
            showingCompletionScreen = true
        }
    }
    
    private func replayVideo() {
        showingCompletionScreen = false
        shouldStopWebPlayback = false
        video.lastPlaybackTime = 0
        if video.type == .local {
            player?.seek(to: .zero) { _ in
                player?.play()
            }
        } else {
            webPlaybackStartTime = 0
            webPlayerReloadID = UUID()
        }
    }

    private func continueToNextVideo() {
        showingCompletionScreen = false
        guard onFolderPage?(.up) == true else {
            finishSessionAndDismiss()
            return
        }
        _ = recordFocusedSegment()
        persistCurrentPlaybackPosition()
    }
    
    private func playbackErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private static func makeLocalPlayer(for video: VideoItem) -> AVPlayer? {
        guard video.type == .local else { return nil }
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDirectory.appendingPathComponent(video.urlString)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        let player = AVPlayer(url: fileURL)
        if let lastTime = validPlaybackTime(video.requestedPlaybackTime) ?? validPlaybackTime(video.lastPlaybackTime) {
            player.seek(to: CMTime(seconds: lastTime, preferredTimescale: 600))
        }
        return player
    }
    
    private static func validPlaybackTime(_ seconds: Double?) -> Double? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }
    
#if canImport(UIKit)
    private func enableStudyFeedOrientation() {
        AppOrientation.shared.supportedOrientations = [.portrait, .landscapeLeft, .landscapeRight]
        refreshSupportedOrientations()
    }
    
    private func restorePortraitOrientation() {
        AppOrientation.shared.supportedOrientations = .portrait
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        refreshSupportedOrientations()
    }
    
    private func refreshSupportedOrientations() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.windows.first { $0.isKeyWindow }?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
#else
    private func enableStudyFeedOrientation() {}
    private func restorePortraitOrientation() {}
#endif
    
    // MARK: - Close Reminders
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            didScheduleCloseReminders = false
            didStartResumeLiveActivity = false
            cancelCloseReminderNotifications()
            StudyResumeActivityManager.endAll()
            if oldPhase == .background || oldPhase == .inactive {
                video.lastWatchedAt = Date()
                setupPlayer()
            }
        case .inactive:
            startResumeLiveActivityIfNeeded()
        case .background:
            scheduleCloseReminderNotificationsIfNeeded()
        @unknown default:
            break
        }
    }

    private func startResumeLiveActivityIfNeeded() {
        guard !didStartResumeLiveActivity else { return }
        guard StudyPreferences.closeRemindersEnabled else { return }
        guard StudyPreferences.canScheduleCloseReminderEvent() else { return }

        let elapsed = Date().timeIntervalSince(sessionStartTime)
        guard elapsed >= 10 else { return }

        didStartResumeLiveActivity = true
        StudyResumeActivityManager.start(video: video)
    }
    
    private var closeReminderNotificationIDs: [String] {
        ["immediate", "5min", "10min"].map {
            "study-close-reminder-\(video.id.uuidString)-\($0)"
        }
    }
    
    private func requestStudyReminderAuthorization() {
        guard StudyPreferences.closeRemindersEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func scheduleCloseReminderNotificationsIfNeeded() {
        guard !didScheduleCloseReminders else { return }
        guard StudyPreferences.closeRemindersEnabled else { return }
        guard StudyPreferences.canScheduleCloseReminderEvent() else {
            debugCloseReminderLog("daily close reminder limit reached")
            return
        }
        
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        guard elapsed >= 10 else { return }
        
        didScheduleCloseReminders = true
        persistCurrentPlaybackPosition()
        
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                debugCloseReminderLog("notification authorization unavailable: \(settings.authorizationStatus.rawValue)")
                return
            }
            
            center.removePendingNotificationRequests(withIdentifiers: closeReminderNotificationIDs)
            debugCloseReminderLog("scheduling close reminders after \(Int(elapsed))s")
            StudyPreferences.recordCloseReminderEvent()
            Task { @MainActor in
                SelovaAnalytics.track(.closeReminderScheduled, properties: [
                    "video_source": video.typeRawValue,
                    "reminder_count": 3,
                    "threshold_seconds": 10
                ])
            }
            
            let title = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = title.isEmpty ? "学習動画" : title
            let reminders: [(id: String, delay: TimeInterval?, body: String)] = [
                (
                    "immediate",
                    nil,
                    "ここで止めると、再開が少し面倒になります。いま戻るのが正解です。"
                ),
                (
                    "5min",
                    5 * 60,
                    "5分経ちました。先延ばしにしないほうが楽です。短く戻りましょう。"
                ),
                (
                    "10min",
                    10 * 60,
                    "10分経ちました。そろそろ戻りましょう。長く空けるほど再開が重くなります。"
                )
            ]
            
            for reminder in reminders {
                let content = UNMutableNotificationContent()
                content.title = displayTitle
                content.body = reminder.body
                content.sound = .default
                content.categoryIdentifier = "study-close-reminder"
                content.userInfo = [
                    "source": SelovaResumeRequest.Source.closeReminder.rawValue,
                    "video_id": video.id.uuidString,
                    "reminder_id": reminder.id
                ]
                
                let trigger = reminder.delay.map {
                    UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false)
                }
                let request = UNNotificationRequest(
                    identifier: "study-close-reminder-\(video.id.uuidString)-\(reminder.id)",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { error in
                    if let error {
                        debugCloseReminderLog("failed to schedule \(reminder.id): \(error.localizedDescription)")
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                center.getPendingNotificationRequests { requests in
                    let pendingIDs = requests
                        .map(\.identifier)
                        .filter { closeReminderNotificationIDs.contains($0) }
                    debugCloseReminderLog("pending close reminders: \(pendingIDs.count)")
                }
            }
        }
    }
    
    private func persistCurrentPlaybackPosition() {
        if let player,
           let currentTime = Self.validPlaybackTime(player.currentTime().seconds) {
            video.lastPlaybackTime = currentTime
        }
        video.lastWatchedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            playbackError = "再生位置を保存できませんでした"
            print("Failed to save playback position: \(error)")
        }
    }

    private func recordFocusedSegment() -> TimeInterval {
        let duration = max(0, Date().timeIntervalSince(sessionStartTime))
        guard duration > 0 else { return 0 }
        let playbackEndTime = currentPlaybackTime ?? sessionPlaybackStartTime
        let focusedDuration = min(
            duration,
            max(0, playbackEndTime - sessionPlaybackStartTime)
        )
        let session = StudySession(
            startTime: sessionStartTime,
            duration: duration,
            focusedDuration: focusedDuration
        )
        modelContext.insert(session)
        SelovaAnalytics.track(.studySessionRecorded, properties: [
            "duration_seconds": duration,
            "focused_seconds": focusedDuration,
            "focus_rate": duration > 0 ? focusedDuration / duration : 0,
            "video_source": video.typeRawValue
        ])
        return duration
    }

    private func recordScrollAwayEvent() {
        guard let playbackTime = currentPlaybackTime,
              playbackTime.isFinite,
              playbackTime >= 0 else {
            return
        }
        let event = VideoAttentionEvent(playbackTime: playbackTime, video: video)
        modelContext.insert(event)
        _ = recordFocusedSegment()
    }
    
    private func updateWebPlaybackProgress(currentTime: Double, duration: Double?) {
        guard !showingCompletionScreen else { return }
        guard let currentTime = Self.validPlaybackTime(currentTime) else { return }
        let validDuration = duration.flatMap { value -> Double? in
            guard value.isFinite, value > 0 else { return nil }
            return value
        }

        if let validDuration,
           currentTime >= max(validDuration - 0.75, validDuration * 0.98) {
            video.duration = validDuration
            video.lastPlaybackTime = validDuration
            completePlayback()
            return
        }

        let now = Date()
        let currentSecond = Int(currentTime.rounded(.down))
        let durationChanged: Bool
        if let validDuration {
            durationChanged = lastPersistedWebDuration.map { abs($0 - validDuration) > 0.5 } ?? true
        } else {
            durationChanged = false
        }
        let progressedEnough = lastPersistedWebPlaybackSecond < 0 || abs(currentSecond - lastPersistedWebPlaybackSecond) >= 5
        let waitedEnough = now.timeIntervalSince(lastWebProgressSaveTime) >= 5

        guard durationChanged || (progressedEnough && waitedEnough) else { return }

        video.lastPlaybackTime = currentTime
        if let validDuration {
            video.duration = validDuration
            lastPersistedWebDuration = validDuration
        }
        video.lastWatchedAt = now
        do {
            try modelContext.save()
            lastWebProgressSaveTime = now
            lastPersistedWebPlaybackSecond = currentSecond
        } catch {
            modelContext.rollback()
            playbackError = "再生位置を保存できませんでした"
            print("Failed to save web playback progress: \(error)")
        }
    }
    
    private func cancelCloseReminderNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: closeReminderNotificationIDs)
    }

    private var notesSheet: some View {
        VideoNotesSheet(
            video: video,
            currentTime: currentPlaybackTime,
            isInStudyMode: true,
            onJump: seekToTimestamp
        )
        .presentationDetents([.fraction(0.50), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(TikTokTheme.background)
    }
    
}

private func debugCloseReminderLog(_ message: String) {
#if DEBUG
    print("[StudyCloseReminder] \(message)")
#endif
}

private struct LocalAVPlayerControllerView: UIViewControllerRepresentable {
    var player: AVPlayer?
    var videoGravity: AVLayerVideoGravity
    var autoPlay: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = videoGravity
        controller.updatesNowPlayingInfoCenter = true
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        player?.allowsExternalPlayback = false
        controller.view.backgroundColor = .black
        if autoPlay, let player, player.rate == 0 {
            player.play()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        uiViewController.videoGravity = videoGravity
        if autoPlay, let player, player.rate == 0 {
            player.play()
        }
    }
}

private struct WebPlayerDescriptor: Equatable {
    enum Provider: String {
        case youtube
        case vimeo
    }
    
    var provider: Provider
    var videoID: String
    var sourceURLString: String?
    
    var key: String {
        "\(provider.rawValue)-\(videoID)-\(sourceURLString ?? "")"
    }
}

private struct WebViewPlayerFixed: UIViewRepresentable {
    var descriptor: WebPlayerDescriptor
    var startTime: Double
    var reloadID: UUID
    var isStopped: Bool
    var pauseToken: UUID
    var onProgress: (_ currentTime: Double, _ duration: Double?) -> Void
    var onComplete: () -> Void
    var onError: (String) -> Void
    
    private static var webViewCache: [String: WKWebView] = [:]
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onProgress: onProgress,
            onComplete: onComplete,
            onError: onError
        )
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = Self.webView(for: descriptor.key)
        configure(webView: webView, context: context)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        configure(webView: uiView, context: context)
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stopPlayback(in: uiView)
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "selovaPlayer")
        uiView.navigationDelegate = nil
    }
    
    private func configure(webView: WKWebView, context: Context) {
        context.coordinator.onProgress = onProgress
        context.coordinator.onComplete = onComplete
        context.coordinator.onError = onError
        
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "selovaPlayer")
        webView.configuration.userContentController.add(context.coordinator, name: "selovaPlayer")
        
        if isStopped {
            context.coordinator.stopPlayback(in: webView)
            return
        }
        
        context.coordinator.didStopPlayback = false
        context.coordinator.pausePlaybackIfNeeded(in: webView, token: pauseToken)
        let nextKey = "\(descriptor.key)-\(reloadID.uuidString)-\(Int(startTime.rounded()))"
        if webView.selovaLoadedKey != nextKey {
            webView.selovaLoadedKey = nextKey
            webView.loadHTMLString(playerHTML, baseURL: URL(string: "https://selova.local"))
        }
    }
    
    private static func webView(for key: String) -> WKWebView {
        if let cached = webViewCache[key] {
            return cached
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webViewCache[key] = webView
        return webView
    }
    
    private var playerHTML: String {
        switch descriptor.provider {
        case .youtube:
            return youtubeHTML(videoID: descriptor.videoID, startTime: startTime)
        case .vimeo:
            return vimeoHTML(videoURLString: descriptor.sourceURLString ?? "", startTime: startTime)
        }
    }
    
    private func youtubeHTML(videoID: String, startTime: Double) -> String {
        let escapedID = videoID.javascriptEscaped
        let start = max(0, Int(startTime.rounded(.down)))
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
        html, body, #player { margin: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
        iframe { width: 100%; height: 100%; border: 0; background: #000; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.selovaPlayer;
        const post = (payload) => { if (bridge) bridge.postMessage(payload); };
        let player;
        let progressTimer;
        let lastReportedSecond = -1;
        
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            videoId: '\(escapedID)',
            playerVars: {
              playsinline: 1,
              autoplay: 1,
              rel: 0,
              modestbranding: 1,
              start: \(start),
              enablejsapi: 1,
              origin: 'https://selova.local'
            },
            events: {
              onReady: onReady,
              onStateChange: onStateChange,
              onError: function() { post({ type: 'error' }); }
            }
          });
        }
        
        function onReady() {
          window.selovaPlayerInstance = player;
          if (\(start) > 0) {
            player.seekTo(\(start), true);
          }
          player.playVideo();
          progressTimer = setInterval(reportProgress, 1000);
          reportProgress();
        }
        
        function onStateChange(event) {
          if (event.data === YT.PlayerState.ENDED) {
            reportProgress();
            post({ type: 'ended' });
          } else if (event.data === YT.PlayerState.PLAYING) {
            reportProgress();
          }
        }
        
        function reportProgress() {
          if (!player || !player.getCurrentTime) return;
          const currentTime = Number(player.getCurrentTime()) || 0;
          const duration = Number(player.getDuration()) || 0;
          const second = Math.floor(currentTime);
          if (second !== lastReportedSecond || duration > 0) {
            lastReportedSecond = second;
            post({ type: 'progress', currentTime: currentTime, duration: duration });
          }
        }
        </script>
        </body>
        </html>
        """
    }
    
    private func vimeoHTML(videoURLString: String, startTime: Double) -> String {
        let escapedURL = videoURLString.javascriptEscaped
        let start = max(0, startTime)
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
        html, body, #player { margin: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
        iframe { width: 100%; height: 100%; border: 0; background: #000; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script src="https://player.vimeo.com/api/player.js"></script>
        <script>
        const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.selovaPlayer;
        const post = (payload) => { if (bridge) bridge.postMessage(payload); };
        const player = new Vimeo.Player('player', {
          url: '\(escapedURL)',
          autoplay: true,
          loop: true,
          autopause: false,
          playsinline: true,
          title: false,
          byline: false,
          portrait: false,
          dnt: true
        });
        window.selovaPlayerInstance = player;
        const startTime = \(start);
        
        player.ready().then(function() {
          if (startTime > 0) {
            return player.setCurrentTime(startTime).catch(function(){});
          }
        }).then(function() {
          return player.play().catch(function(){});
        }).catch(function(error) {
          postError(error);
        });
        
        player.on('timeupdate', function(data) {
          post({
            type: 'progress',
            currentTime: data.seconds || 0,
            duration: data.duration || 0
          });
        });
        
        player.on('ended', function(data) {
          post({
            type: 'progress',
            currentTime: data.seconds || data.duration || 0,
            duration: data.duration || 0
          });
          post({ type: 'ended' });
        });
        
        player.on('error', function(error) {
          postError(error);
        });
        
        function postError(error) {
          post({
            type: 'error',
            provider: 'vimeo',
            name: error && error.name ? error.name : 'Error',
            message: error && error.message ? error.message : ''
          });
        }
        </script>
        </body>
        </html>
        """
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onProgress: (_ currentTime: Double, _ duration: Double?) -> Void
        var onComplete: () -> Void
        var onError: (String) -> Void
        var loadedKey: String?
        var didStopPlayback = false
        var lastPauseToken: UUID?
        
        init(
            onProgress: @escaping (_ currentTime: Double, _ duration: Double?) -> Void,
            onComplete: @escaping () -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onProgress = onProgress
            self.onComplete = onComplete
            self.onError = onError
        }
        
        func stopPlayback(in webView: WKWebView) {
            guard !didStopPlayback else { return }
            didStopPlayback = true
            loadedKey = nil
            webView.selovaLoadedKey = nil
            webView.stopLoading()
            webView.evaluateJavaScript(
                "document.querySelectorAll('video').forEach(v => v.pause());",
                completionHandler: nil
            )
            webView.loadHTMLString("<!doctype html><html><body style='margin:0;background:#000'></body></html>", baseURL: nil)
        }
        
        func pausePlaybackIfNeeded(in webView: WKWebView, token: UUID) {
            guard lastPauseToken != token else { return }
            lastPauseToken = token
            webView.evaluateJavaScript(
                """
                (function() {
                  const player = window.selovaPlayerInstance;
                  if (player && player.pauseVideo) { player.pauseVideo(); }
                  if (player && player.pause) { player.pause(); }
                  document.querySelectorAll('video').forEach(v => v.pause());
                })();
                """,
                completionHandler: nil
            )
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }
            
            switch type {
            case "progress":
                let currentTime = doubleValue(from: body["currentTime"]) ?? 0
                let duration = doubleValue(from: body["duration"])
                onProgress(currentTime, duration)
            case "ended":
                onComplete()
            case "error":
                let provider = body["provider"] as? String
                let name = body["name"] as? String
                let message = body["message"] as? String
                onError(videoErrorMessage(provider: provider, name: name, message: message))
            default:
                break
            }
        }
        
        private func videoErrorMessage(provider: String?, name: String?, message: String?) -> String {
            let providerName = provider?.lowercased()
            let errorName = name?.lowercased()
            let errorMessage = message?.lowercased() ?? ""
            
            if providerName == "vimeo" {
                if errorName == "privacyerror" || errorMessage.contains("privacy") {
                    return "Vimeo の埋め込み権限がありません。`h=` 付きURLか、埋め込み許可された動画を使ってください。"
                }
                if errorName == "passworderror" || errorMessage.contains("password") {
                    return "Vimeo 側でパスワード保護されています。"
                }
                if errorMessage.contains("video does not exist") || errorMessage.contains("not found") {
                    return "Vimeo のURLを確認できませんでした。`h=` が必要な動画の可能性があります。"
                }
                return "Vimeo を読み込めませんでした。"
            }
            
            return "動画ページを読み込めません"
        }
        
        private func doubleValue(from value: Any?) -> Double? {
            if let value = value as? Double {
                return value
            }
            if let value = value as? NSNumber {
                return value.doubleValue
            }
            if let value = value as? String {
                return Double(value)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }
        
        private func report(_ error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            onError("動画ページを読み込めません")
        }
    }
}

private extension String {
    var javascriptEscaped: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}

private extension WKWebView {
    private static var selovaLoadedKeyAssociationKey: UInt8 = 0
    
    var selovaLoadedKey: String? {
        get {
            objc_getAssociatedObject(self, &Self.selovaLoadedKeyAssociationKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &Self.selovaLoadedKeyAssociationKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
}
