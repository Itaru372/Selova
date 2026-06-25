import Foundation
import UserNotifications

struct SelovaResumeRequest: Codable {
    enum Source: String, Codable {
        case closeReminder = "close_reminder"
        case liveActivity = "live_activity"
    }

    let source: Source
    let videoID: UUID?
    let reminderID: String?
}

enum SelovaResumeRoute {
    static let notificationName = Notification.Name("SelovaResumeRequested")

    private static let defaultsKey = "selova.pendingResumeRequest"

    static func makeLiveActivityURL(videoID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "selova"
        components.host = "resume"
        components.queryItems = [
            URLQueryItem(name: "source", value: SelovaResumeRequest.Source.liveActivity.rawValue),
            URLQueryItem(name: "video_id", value: videoID)
        ]
        return components.url
    }

    static func request(from url: URL) -> SelovaResumeRequest? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "selova",
              components.host == "resume" else {
            return nil
        }

        let source = components.queryItems?.first(where: { $0.name == "source" })?.value
        let reminderID = components.queryItems?.first(where: { $0.name == "reminder_id" })?.value
        let videoID = components.queryItems?.first(where: { $0.name == "video_id" })?.value

        guard let source, let sourceValue = SelovaResumeRequest.Source(rawValue: source) else {
            return nil
        }

        return SelovaResumeRequest(
            source: sourceValue,
            videoID: videoID.flatMap(UUID.init(uuidString:)),
            reminderID: reminderID
        )
    }

    static func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let sourceRawValue = userInfo["source"] as? String ?? SelovaResumeRequest.Source.closeReminder.rawValue
        guard let source = SelovaResumeRequest.Source(rawValue: sourceRawValue) else { return }

        let request = SelovaResumeRequest(
            source: source,
            videoID: (userInfo["video_id"] as? String).flatMap(UUID.init(uuidString:)),
            reminderID: userInfo["reminder_id"] as? String
        )
        enqueue(request)
    }

    static func consumePendingRequest() -> SelovaResumeRequest? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        return try? JSONDecoder().decode(SelovaResumeRequest.self, from: data)
    }

    private static func enqueue(_ request: SelovaResumeRequest) {
        guard let data = try? JSONEncoder().encode(request) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
}
