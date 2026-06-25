import ActivityKit

struct StudyResumeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var videoTitle: String
        var message: String
    }

    let videoID: String
}
