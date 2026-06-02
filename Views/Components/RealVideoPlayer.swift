import SwiftUI
import AVKit
import WebKit
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct RealVideoPlayer: View {
    var video: VideoItem
    var sharedPlayer: AVPlayer?
    var onPlaybackTimeUpdate: ((Double) -> Void)?

    var body: some View {
        if video.type == .local {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent(video.urlString)
            LocalVideoPlayer(
                url: fileURL,
                video: video,
                player: sharedPlayer,
                managesPlayback: sharedPlayer == nil,
                onPlaybackTimeUpdate: sharedPlayer == nil ? onPlaybackTimeUpdate : nil
            )
        } else if video.type == .youtube, let url = youtubeEmbedURL(from: video.urlString) {
            WebViewPlayer(url: url)
        } else if video.type == .vimeo, let url = vimeoEmbedURL(from: video.urlString) {
            WebViewPlayer(url: url)
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.yellow)
                Text("動画を読み込めません")
                    .foregroundColor(.white)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
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
            URLQueryItem(name: "modestbranding", value: "1")
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
}

struct LocalVideoPlayer: UIViewControllerRepresentable {
    var url: URL
    var video: VideoItem
    var player: AVPlayer?
    var managesPlayback: Bool = true
    var onPlaybackTimeUpdate: ((Double) -> Void)?

    class Coordinator: NSObject {
        var parent: LocalVideoPlayer

        init(_ parent: LocalVideoPlayer) {
            self.parent = parent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let activePlayer = player ?? AVPlayer(url: url)
        controller.player = activePlayer
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect

        if managesPlayback, let lastTime = Self.validPlaybackTime(video.lastPlaybackTime) {
            let cmTime = CMTime(seconds: lastTime, preferredTimescale: 600)
            activePlayer.seek(to: cmTime)
        }

        if managesPlayback {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: activePlayer.currentItem,
                queue: .main
            ) { _ in
                activePlayer.seek(to: .zero)
                activePlayer.play()
            }
            activePlayer.play()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        guard coordinator.parent.managesPlayback else { return }
        if let player = uiViewController.player {
            if let currentTime = Self.validPlaybackTime(player.currentTime().seconds) {
                coordinator.parent.onPlaybackTimeUpdate?(currentTime)
            }
            player.pause()
        }
    }

    private static func validPlaybackTime(_ seconds: Double?) -> Double? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }
}

struct WebViewPlayer: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
