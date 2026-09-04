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
    let location: MemoryLocation?
    let locationCandidates: [MemoryLocationCandidate]
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
        location: MemoryLocation? = nil,
        locationCandidates: [MemoryLocationCandidate] = [],
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
        self.location = location
        self.locationCandidates = locationCandidates
        self.journalIDs = journalIDs
        self.journalNames = journalNames
    }

    func replacingLocation(_ location: MemoryLocation) -> MemorySummary {
        let updatedCandidates = locationCandidates.map { candidate in
            guard candidate.location.representsSamePlace(as: location),
                  candidate.location.normalizedName == nil else {
                return candidate
            }
            return MemoryLocationCandidate(location: location)
        }
        return MemorySummary(
            id: id,
            title: title,
            caption: caption,
            capturedAt: capturedAt,
            thumbnail: thumbnail,
            hasAudio: hasAudio,
            audioFilename: audioFilename,
            audioDurationSeconds: audioDurationSeconds,
            locationName: location.normalizedName,
            location: location,
            locationCandidates: updatedCandidates,
            journalIDs: journalIDs,
            journalNames: journalNames
        )
    }
}
