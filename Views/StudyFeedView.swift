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
                Color.black.ignoresSafeArea()
                videoPage(in: proxy.size)
            }
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
            playerContainer(gravity: .resizeAspect)
                .frame(width: size.width, height: size.height)
                .clipped()
                .offset(y: swipeOffset)

            if let playbackError {
                playbackErrorView(playbackError)
                    .padding(.horizontal, 28)
            }

            backButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
    }

    private func feedSwipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 28)
            .onChanged { value in
                guard video.type == .local else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                swipeOffset = value.translation.height * 0.08
            }
            .onEnded { value in
                guard video.type == .local else {
                    swipeOffset = 0
                    return
                }
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    withAnimation(.smooth(duration: 0.2)) {
                        swipeOffset = 0
                    }
                    return
                }

                let threshold = size.height * 0.12
                if value.translation.height <= -threshold {
                    virtualPage += 1
                } else if value.translation.height >= threshold {
                    virtualPage = max(0, virtualPage - 1)
                }

                withAnimation(.smooth(duration: 0.22)) {
                    swipeOffset = 0
                }
            }
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
        dismiss()
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
