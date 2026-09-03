// Provides compact, Sendable memory data for cards, lists, previews, and view models.

import Foundation

struct MemorySummary: Identifiable, Hashable, Sendable {
    enum Thumbnail: Hashable, Sendable {
        case managedFile(String)
        case previewAsset(String)
    }

    let id: UUID
    let title: String
    let caption: String?
    let capturedAt: Date
    let thumbnail: Thumbnail?
    let hasAudio: Bool
    let audioFilename: String?
    let audioDurationSeconds: Double?
    let locationName: String?
    let journalIDs: Set<UUID>
    let journalNames: [String]

    init(
        id: UUID,
        title: String,
        caption: String?,
        capturedAt: Date,
        thumbnail: Thumbnail?,
        hasAudio: Bool,
        audioFilename: String? = nil,
        audioDurationSeconds: Double?,
        locationName: String?,
        journalIDs: Set<UUID> = [],
        journalNames: [String]
    ) {
        self.id = id
        self.title = title
        self.caption = caption
        self.capturedAt = capturedAt
        self.thumbnail = thumbnail
        self.hasAudio = hasAudio
        self.audioFilename = audioFilename
        self.audioDurationSeconds = audioDurationSeconds
        self.locationName = locationName
        self.journalIDs = journalIDs
        self.journalNames = journalNames
    }
}
