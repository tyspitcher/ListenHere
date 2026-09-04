// Describes the complete editable content snapshot for an existing memory.

import Foundation

struct MemoryContentUpdate: Equatable, Sendable {
    let title: String?
    let caption: String?
    let capturedAt: Date
    let photoFilename: String?
    let audioFilename: String?
    let audioDurationSeconds: Double?
    let journalIDs: Set<UUID>?
    let location: MemoryLocation?
    let shouldUpdateLocation: Bool
    let locationCandidates: [MemoryLocationCandidate]?

    init(
        title: String?,
        caption: String?,
        capturedAt: Date,
        photoFilename: String?,
        audioFilename: String?,
        audioDurationSeconds: Double?,
        journalIDs: Set<UUID>? = nil,
        location: MemoryLocation? = nil,
        shouldUpdateLocation: Bool = false,
        locationCandidates: [MemoryLocationCandidate]? = nil
    ) {
        self.title = title
        self.caption = caption
        self.capturedAt = capturedAt
        self.photoFilename = photoFilename
        self.audioFilename = audioFilename
        self.audioDurationSeconds = audioDurationSeconds
        self.journalIDs = journalIDs
        self.location = location
        self.shouldUpdateLocation = shouldUpdateLocation
        self.locationCandidates = locationCandidates
    }
}
