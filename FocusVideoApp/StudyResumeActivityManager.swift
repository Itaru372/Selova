import ActivityKit
import Foundation

@MainActor
enum StudyResumeActivityManager {
    static func start(video: VideoItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        endAll()

        let title = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = StudyResumeActivityAttributes.ContentState(
            videoTitle: title.isEmpty ? String(localized: "学習動画") : title,
            message: String(localized: "Selova に戻って、続きを見よう")
        )
        let attributes = StudyResumeActivityAttributes(videoID: video.id.uuidString)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            SelovaAnalytics.trackImmediately(.liveActivityStarted, properties: [
                "video_source": video.typeRawValue
            ])
        } catch {
            debugStudyResumeActivityLog("failed to start: \(error.localizedDescription)")
        }
    }

    static func endAll() {
        for activity in Activity<StudyResumeActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

private func debugStudyResumeActivityLog(_ message: String) {
#if DEBUG
    print("[StudyResumeActivity] \(message)")
#endif
}
