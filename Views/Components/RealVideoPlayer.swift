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
        var videoId = ""
        if let url = URL(string: urlString) {
            if url.host?.contains("youtu.be") == true {
                videoId = url.lastPathComponent
            } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems,
                      let id = queryItems.first(where: { $0.name == "v" })?.value {
                videoId = id
            }
        }
        
        if !videoId.isEmpty {
            return URL(string: "https://www.youtube.com/embed/\(videoId)?playsinline=1&autoplay=1&loop=1&playlist=\(videoId)")
        }
        return nil
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
        
        if managesPlayback, let lastTime = video.lastPlaybackTime {
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
            let currentTime = player.currentTime().seconds
            if !currentTime.isNaN {
                coordinator.parent.onPlaybackTimeUpdate?(currentTime)
            }
            player.pause()
        }
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
