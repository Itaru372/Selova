import XCTest
@testable import FocusVideoApp

@MainActor
final class StudyProgressTests: XCTestCase {
    func testPlaybackPositionTextUsesLastPlaybackTime() {
        let video = VideoItem(
            title: "Long lesson",
            urlString: "lesson.mov",
            type: .local,
            duration: 82 * 60 + 26
        )
        video.lastPlaybackTime = 24 * 60 + 6

        XCTAssertEqual(StudyProgress.playbackPositionText(for: video), "24分6秒まで / 82分26秒")
        XCTAssertEqual(StudyProgress.compactPlaybackPositionText(for: video), "24:06 / 82:26")
        XCTAssertEqual(StudyProgress.statusText(for: video), "続きから")
        XCTAssertEqual(StudyProgress.progress(for: video), (24 * 60 + 6) / Double(82 * 60 + 26), accuracy: 0.0001)
    }

    func testPlaybackPositionTextShowsUnwatched() {
        let video = VideoItem(
            title: "Fresh lesson",
            urlString: "lesson.mov",
            type: .local,
            createdAt: Date(timeIntervalSinceNow: -5 * 24 * 60 * 60),
            duration: 120
        )

        XCTAssertEqual(StudyProgress.playbackPositionText(for: video), "未視聴")
        XCTAssertEqual(StudyProgress.compactPlaybackPositionText(for: video), "未視聴")
        XCTAssertEqual(StudyProgress.statusText(for: video), "未視聴")
        XCTAssertEqual(StudyProgress.progress(for: video), 0)
    }

    func testRecommendationScorePrioritizesAlmostFinishedAndContinueCandidates() {
        let almostFinished = VideoItem(
            title: "Almost finished",
            urlString: "a.mov",
            type: .local,
            duration: 100
        )
        almostFinished.lastPlaybackTime = 94
        almostFinished.lastWatchedAt = Date()

        let continueCandidate = VideoItem(
            title: "Continue",
            urlString: "b.mov",
            type: .local,
            duration: 100
        )
        continueCandidate.lastPlaybackTime = 40
        continueCandidate.lastWatchedAt = Date()

        let unwatched = VideoItem(
            title: "Unwatched",
            urlString: "c.mov",
            type: .local,
            createdAt: Date(timeIntervalSinceNow: -3 * 24 * 60 * 60),
            duration: 100
        )

        XCTAssertGreaterThan(
            StudyProgress.recommendationScore(for: almostFinished),
            StudyProgress.recommendationScore(for: continueCandidate)
        )
        XCTAssertGreaterThan(
            StudyProgress.recommendationScore(for: continueCandidate),
            StudyProgress.recommendationScore(for: unwatched)
        )
    }

    func testRecommendationScoreBoostsRecentFolderContext() {
        let focusFolder = FolderItem(name: "数学")
        let otherFolder = FolderItem(name: "英語")

        let focusVideo = VideoItem(
            title: "Same folder",
            urlString: "same.mov",
            type: .local,
            createdAt: Date(timeIntervalSinceNow: -5 * 24 * 60 * 60),
            duration: 100
        )
        focusVideo.folder = focusFolder

        let otherVideo = VideoItem(
            title: "Other folder",
            urlString: "other.mov",
            type: .local,
            createdAt: focusVideo.createdAt,
            duration: 100
        )
        otherVideo.folder = otherFolder

        XCTAssertGreaterThan(
            StudyProgress.recommendationScore(for: focusVideo, focusFolderID: focusFolder.id),
            StudyProgress.recommendationScore(for: otherVideo, focusFolderID: focusFolder.id)
        )
    }

    func testStudyGrowthRequiredXPIncreasesByLevel() {
        XCTAssertLessThan(
            StudyGrowth.requiredXPToAdvance(from: 1),
            StudyGrowth.requiredXPToAdvance(from: 2)
        )
        XCTAssertLessThan(
            StudyGrowth.requiredXPToAdvance(from: 2),
            StudyGrowth.requiredXPToAdvance(from: 3)
        )
    }

    func testStudyGrowthLevelStateUsesXPAndStreakBonus() {
        let withoutStreak = StudyGrowth.levelState(totalFocusedTime: 10 * 60, streakDays: 0)
        let withStreak = StudyGrowth.levelState(totalFocusedTime: 10 * 60, streakDays: 3)

        XCTAssertEqual(withoutStreak.xp, 100)
        XCTAssertGreaterThan(withStreak.xp, withoutStreak.xp)
        XCTAssertGreaterThanOrEqual(withStreak.level, withoutStreak.level)
    }

    func testStudyGrowthUsesFocusedMinutesInsteadOfCompletionCount() {
        XCTAssertEqual(
            StudyGrowth.totalXP(totalFocusedTime: 10 * 60, streakDays: 0),
            100
        )
    }

    func testAttentionGapsOnlyAppearForCompletedVideosWithRepeatedScrolls() {
        let video = VideoItem(
            title: "Completed lesson",
            urlString: "lesson.mov",
            type: .local,
            duration: 10 * 60
        )
        video.completionCount = 1
        let first = VideoAttentionEvent(playbackTime: 2 * 60, video: video)
        let second = VideoAttentionEvent(playbackTime: 2 * 60 + 40, video: video)
        let separate = VideoAttentionEvent(playbackTime: 7 * 60, video: video)
        video.attentionEvents = [first, second, separate]

        let gaps = StudyProgress.attentionGaps(for: video)

        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps[0].startTime, 90, accuracy: 0.001)
        XCTAssertEqual(gaps[0].endTime, 205, accuracy: 0.001)
        XCTAssertEqual(gaps[0].rangeText, "1:30〜3:25")
    }

    func testVideoTimestampFormatterParsesManualTimestamps() {
        XCTAssertEqual(VideoTimestampFormatter.seconds(from: "20:15"), 20 * 60 + 15)
        XCTAssertEqual(VideoTimestampFormatter.seconds(from: "1:05:30"), 1 * 3600 + 5 * 60 + 30)
        XCTAssertNil(VideoTimestampFormatter.seconds(from: "1:80"))
        XCTAssertNil(VideoTimestampFormatter.seconds(from: "abc"))
    }

    func testVideoTimestampFormatterFormatsTimestamps() {
        XCTAssertEqual(VideoTimestampFormatter.string(from: 20 * 60 + 15), "20:15")
        XCTAssertEqual(VideoTimestampFormatter.string(from: 1 * 3600 + 5 * 60 + 30), "1:05:30")
    }
}
