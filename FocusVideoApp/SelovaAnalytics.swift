import Foundation
import PostHog

@MainActor
enum SelovaAnalytics {
    enum Event: String {
        case appLaunched = "app launched"
        case screenViewed = "screen viewed"
        case tabSelected = "tab selected"
        case videoAdded = "video added"
        case videoStarted = "video started"
        case videoCompleted = "video completed"
        case studySessionRecorded = "study session recorded"
        case feedPaged = "study feed paged"
        case notesOpened = "notes opened"
        case folderCreated = "folder created"
        case settingChanged = "setting changed"
        case focusInsightsViewed = "focus insights viewed"
        case recommendationTapped = "recommendation tapped"
        case closeReminderScheduled = "close reminder scheduled"
        case liveActivityStarted = "live activity started"
        case returnToStudy = "return to study"
    }

    private static var isConfigured = false

    static func configure() {
        guard !isConfigured else { return }

        let configuration = PostHogConfig(
            projectToken: "phc_BYVZnaHUUMtXDT2dprHQPsb9bZSbpDKqhgM8zH7X2gRM",
            host: "https://us.i.posthog.com"
        )
        configuration.captureScreenViews = false
        configuration.captureApplicationLifecycleEvents = false
        configuration.captureElementInteractions = false
        configuration.sessionReplay = false
        configuration.flushAt = 1
        configuration.flushIntervalSeconds = 5
        PostHogSDK.shared.setup(configuration)
        isConfigured = true
    }

    static func track(_ event: Event, properties: [String: Any] = [:]) {
        guard isConfigured else { return }
        var privacySafeProperties = properties
        privacySafeProperties["$geoip_disable"] = true
        PostHogSDK.shared.capture(event.rawValue, properties: privacySafeProperties)
    }

    static func trackImmediately(_ event: Event, properties: [String: Any] = [:]) {
        track(event, properties: properties)
        PostHogSDK.shared.flush()
    }

    static func trackScreen(_ name: String) {
        track(.screenViewed, properties: ["screen_name": name])
    }
}
