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
    var thumbnailData: Data?
    
    var folder: FolderItem?
    
    var type: VideoType {
        get { VideoType(rawValue: typeRawValue) ?? .youtube }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), title: String, urlString: String, type: VideoType, createdAt: Date = Date(), duration: TimeInterval = 0, watchedDuration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.typeRawValue = type.rawValue
        self.createdAt = createdAt
        self.duration = duration
        self.watchedDuration = watchedDuration
    }
}

@Model
final class StudySession {
    var id: UUID
    var startTime: Date
    var duration: TimeInterval
    
    init(id: UUID = UUID(), startTime: Date = Date(), duration: TimeInterval = 0) {
        self.id = id
        self.startTime = startTime
        self.duration = duration
    }
}
