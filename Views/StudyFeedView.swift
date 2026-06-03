import SwiftUI
import AVKit
import WebKit
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct StudyFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var video: VideoItem
    @State private var sessionStartTime = Date()
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var itemStatusObserver: NSKeyValueObservation?
    @State private var playbackError: String?
    @State private var swipeOffset: CGFloat = 0
    @State private var virtualPage = 0
    @State private var isPaging = false
    @State private var isDismissing = false

    init(video: VideoItem) {
        self.video = video
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
                sessionStartTime = Date()
                video.lastWatchedAt = Date()
                setupPlayer()
            }
            .onDisappear {
                stopPlayer()
            }
        }
    }

    private func videoPage(in size: CGSize) -> some View {
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

            pageEdgeIndicator(in: size)
                .opacity(abs(swipeOffset) > 12 ? 1 : 0.45)
                .animation(.smooth(duration: 0.18), value: swipeOffset)
                .zIndex(2)

            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
                    .zIndex(2)
            }

            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.82))

            content()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
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

    private func pageEdgeIndicator(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            edgeCapsule
                .offset(y: 20)
            Spacer()
            edgeCapsule
                .offset(y: -20)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private var edgeCapsule: some View {
        Capsule()
            .fill(Color.white.opacity(0.76))
            .frame(width: 46, height: 4)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        .background(Color.black.opacity(0.32), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func feedSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 28)
            .onChanged { value in
                guard size.height >= size.width else { return }
                guard !isPaging else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                swipeOffset = clamped(value.translation.height, min: -size.height, max: size.height)
            }
            .onEnded { value in
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

    private enum FeedSwipeDirection {
        case up
        case down
    }

    private func finishVirtualPageSwipe(_ direction: FeedSwipeDirection, height: CGFloat) {
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
            isPaging = false
            player?.play()
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
            } else if let url = embedURL {
                webPlayerView(url: url)
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

    private func webPlayerView(url: URL) -> some View {
        WebViewPlayerFixed(url: url) { message in
            playbackError = message
        }
        .onAppear {
            playbackError = nil
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

        if let lastTime = Self.validPlaybackTime(video.lastPlaybackTime) {
            let cmTime = CMTime(seconds: lastTime, preferredTimescale: 600)
            activePlayer.seek(to: cmTime)
        }

        observePlaybackStatus(for: activePlayer)

        if endObserver == nil {
            let observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: activePlayer.currentItem,
                queue: .main
            ) { _ in
                activePlayer.seek(to: .zero)
                activePlayer.play()
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
                    if player.rate == 0 {
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
        FrictionBackButton(onDismiss: finishSessionAndDismiss)
            .padding(.leading, 20)
            .padding(.top, 54)
    }

    private var embedURL: URL? {
        switch video.type {
        case .youtube:
            return youtubeEmbedURL(from: video.urlString)
        case .vimeo:
            return vimeoEmbedURL(from: video.urlString)
        case .local:
            return nil
        }
    }

    private func youtubeEmbedURL(from urlString: String) -> URL? {
        guard let videoId = youtubeVideoID(from: urlString) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube-nocookie.com"
        components.path = "/embed/\(videoId)"
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "loop", value: "1"),
            URLQueryItem(name: "playlist", value: videoId),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "origin", value: "https://www.youtube.com")
        ]
        return components.url
    }

    private func youtubeVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.contains("/") && !trimmed.contains("?") && trimmed.count >= 6 {
            return trimmed
        }

        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !id.isEmpty {
            return sanitizedVideoID(id)
        }

        let host = (components.host ?? url.host ?? "").lowercased()
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if host.contains("youtu.be") {
            return pathParts.first.flatMap(sanitizedVideoID)
        }

        for marker in ["shorts", "embed", "live", "v"] {
            if let index = pathParts.firstIndex(of: marker),
               pathParts.indices.contains(index + 1) {
                return sanitizedVideoID(pathParts[index + 1])
            }
        }

        return nil
    }

    private func sanitizedVideoID(_ value: String) -> String? {
        let id = value
            .split(separator: "?").first?
            .split(separator: "&").first
            .map(String.init) ?? value
        return id.isEmpty ? nil : id
    }

    private func vimeoEmbedURL(from urlString: String) -> URL? {
        if let url = URL(string: urlString) {
            let videoId = url.lastPathComponent
            return URL(string: "https://player.vimeo.com/video/\(videoId)?autoplay=1&loop=1&autopause=0")
        }
        return nil
    }

    private func finishSessionAndDismiss() {
        guard !isDismissing else { return }

        let duration = Date().timeIntervalSince(sessionStartTime)
        let session = StudySession(startTime: sessionStartTime, duration: duration)
        modelContext.insert(session)

        if let player {
            if let currentTime = Self.validPlaybackTime(player.currentTime().seconds) {
                video.lastPlaybackTime = currentTime
            }
            player.pause()
        }
        video.watchedDuration += duration
        try? modelContext.save()

        withAnimation(.smooth(duration: 0.22)) {
            isDismissing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dismiss()
        }
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
        if let lastTime = validPlaybackTime(video.lastPlaybackTime) {
            player.seek(to: CMTime(seconds: lastTime, preferredTimescale: 600))
        }
        return player
    }

    private static func validPlaybackTime(_ seconds: Double?) -> Double? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }

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
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
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

private struct WebViewPlayerFixed: UIViewRepresentable {
    var url: URL
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onError: (String) -> Void

        init(onError: @escaping (String) -> Void) {
            self.onError = onError
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
