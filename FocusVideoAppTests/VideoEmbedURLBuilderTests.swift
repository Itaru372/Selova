import XCTest
@testable import FocusVideoApp

final class VideoEmbedURLBuilderTests: XCTestCase {
    func testYouTubeWatchURLBuildsNoCookieEmbedURL() {
        let url = VideoEmbedURLBuilder.youtubeEmbedURL(
            from: "https://www.youtube.com/watch?v=abc123XYZ_-&t=90s"
        )

        XCTAssertEqual(url?.host, "www.youtube-nocookie.com")
        XCTAssertEqual(url?.path, "/embed/abc123XYZ_-")
        XCTAssertTrue(url?.absoluteString.contains("playlist=abc123XYZ_-") == true)
    }

    func testYouTubeShortsAndShortURLExtractIDs() {
        XCTAssertEqual(
            VideoEmbedURLBuilder.youtubeVideoID(from: "https://youtube.com/shorts/shortID99"),
            "shortID99"
        )
        XCTAssertEqual(
            VideoEmbedURLBuilder.youtubeVideoID(from: "https://youtu.be/shortURL77?si=share"),
            "shortURL77"
        )
    }

    func testVimeoURLVariantsBuildEmbedURL() {
        let standard = VideoEmbedURLBuilder.vimeoEmbedURL(from: "https://vimeo.com/123456789")
        let player = VideoEmbedURLBuilder.vimeoEmbedURL(from: "https://player.vimeo.com/video/987654321")
        let raw = VideoEmbedURLBuilder.vimeoEmbedURL(from: "13579")

        XCTAssertEqual(standard?.absoluteString, "https://player.vimeo.com/video/123456789?autoplay=1&loop=1&autopause=0")
        XCTAssertEqual(player?.path, "/video/987654321")
        XCTAssertEqual(raw?.path, "/video/13579")
    }
}
