import Foundation

enum VideoEmbedURLBuilder {
    static func embedURL(for video: VideoItem) -> URL? {
        switch video.type {
        case .youtube:
            return youtubeEmbedURL(from: video.urlString)
        case .vimeo:
            return vimeoEmbedURL(from: video.urlString)
        case .local:
            return nil
        }
    }

    nonisolated static func youtubeEmbedURL(from urlString: String) -> URL? {
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

    nonisolated static func vimeoEmbedURL(from urlString: String) -> URL? {
        guard let videoId = vimeoVideoID(from: urlString) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "player.vimeo.com"
        components.path = "/video/\(videoId)"
        components.queryItems = [
            URLQueryItem(name: "autoplay", value: "1"),
            URLQueryItem(name: "loop", value: "1"),
            URLQueryItem(name: "autopause", value: "0")
        ]
        return components.url
    }

    nonisolated static func youtubeVideoID(from urlString: String) -> String? {
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

    nonisolated static func vimeoVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.allSatisfy(\.isNumber) {
            return trimmed
        }

        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized) else { return nil }
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if let videoIndex = pathParts.firstIndex(of: "video"),
           pathParts.indices.contains(videoIndex + 1),
           pathParts[videoIndex + 1].allSatisfy(\.isNumber) {
            return pathParts[videoIndex + 1]
        }

        return pathParts.last { part in
            part.allSatisfy(\.isNumber)
        }
    }

    nonisolated private static func sanitizedVideoID(_ value: String) -> String? {
        let id = value
            .split(separator: "?").first?
            .split(separator: "&").first
            .map(String.init) ?? value
        return id.isEmpty ? nil : id
    }
}
