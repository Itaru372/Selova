import Foundation
import SwiftData

@Model
final class FolderItem {
    var id: UUID
    var name: String
    var createdAt: Date
    
    // Self-referential relationship for folder hierarchy
    @Relationship(deleteRule: .cascade, inverse: \FolderItem.parent)
    var children: [FolderItem]?
    
    var parent: FolderItem?
    
    @Relationship(deleteRule: .cascade, inverse: \VideoItem.folder)
    var videos: [VideoItem]?
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), parent: FolderItem? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.parent = parent
    }
}

enum VideoType: String, Codable {
    case youtube
    case vimeo
    case local
}

@Model
final class VideoItem {
    var id: UUID
    var title: String
    var urlString: String
    var typeRawValue: String
    var createdAt: Date
    var duration: TimeInterval
    var watchedDuration: TimeInterval
    var lastWatchedAt: Date?
    var lastPlaybackTime: Double?
    var completionCount: Int?
    var thumbnailData: Data?

    @Transient
    var requestedPlaybackTime: Double?
    
    var folder: FolderItem?

    @Relationship(deleteRule: .cascade, inverse: \VideoNote.video)
    var notes: [VideoNote]?

    @Relationship(deleteRule: .cascade, inverse: \VideoAttentionEvent.video)
    var attentionEvents: [VideoAttentionEvent]?
    
    var type: VideoType {
        get { VideoType(rawValue: typeRawValue) ?? .youtube }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), title: String, urlString: String, type: VideoType, createdAt: Date = Date(), duration: TimeInterval = 0, watchedDuration: TimeInterval = 0, completionCount: Int? = nil) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.typeRawValue = type.rawValue
        self.createdAt = createdAt
        self.duration = duration
        self.watchedDuration = watchedDuration
        self.completionCount = completionCount
    }
}

@Model
final class VideoNote {
    var id: UUID
    var timestamp: TimeInterval
    var text: String
    var createdAt: Date
    var updatedAt: Date

    var video: VideoItem?

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        video: VideoItem? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.video = video
    }
}

@Model
final class VideoAttentionEvent {
    var id: UUID
    var playbackTime: TimeInterval
    var createdAt: Date

    var video: VideoItem?

    init(
        id: UUID = UUID(),
        playbackTime: TimeInterval,
        createdAt: Date = Date(),
        video: VideoItem? = nil
    ) {
        self.id = id
        self.playbackTime = playbackTime
        self.createdAt = createdAt
        self.video = video
    }
}

@Model
final class StudySession {
    var id: UUID
    var startTime: Date
    var duration: TimeInterval
    var focusedDuration: TimeInterval = 0
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        duration: TimeInterval = 0,
        focusedDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.duration = duration
        self.focusedDuration = focusedDuration ?? duration
    }
}
