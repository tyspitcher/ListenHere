// Defines the SwiftData memory model, media references, journal relationships, location, and deletion state.

import Foundation
import SwiftData

@Model
final class Memory {
    #Index<Memory>([\.capturedAt], [\.createdAt], [\.deletedAt, \.capturedAt])

    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var capturedAt: Date = Date()
    var deletedAt: Date?
    var deletionBatchID: UUID?
    var title: String?
    var caption: String?
    var photoFilename: String?
    var audioFilename: String?
    var audioDurationSeconds: Double?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var locationSourceRawValue: String?
    var locationCandidatesData: Data?
    var journals: [Journal]?

    @Relationship(deleteRule: .cascade, inverse: \PhotoEditRecipe.memory)
    var photoEditRecipe: PhotoEditRecipe?

    @Relationship(deleteRule: .cascade, inverse: \AudioEditRecipe.memory)
    var audioEditRecipe: AudioEditRecipe?

    @Relationship(deleteRule: .cascade, inverse: \MemoryPresentationRecipe.memory)
    var presentationRecipe: MemoryPresentationRecipe?

    @Relationship(deleteRule: .cascade, inverse: \MemoryDecorationPlacement.memory)
    var decorations: [MemoryDecorationPlacement]?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        capturedAt: Date,
        title: String? = nil,
        caption: String? = nil,
        photoFilename: String? = nil,
        audioFilename: String? = nil,
        audioDurationSeconds: Double? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.capturedAt = capturedAt
        self.title = title
        self.caption = caption
        self.photoFilename = photoFilename
        self.audioFilename = audioFilename
        self.audioDurationSeconds = audioDurationSeconds
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var location: MemoryLocation? {
        guard let latitude, let longitude else { return nil }
        return MemoryLocation(
            latitude: latitude,
            longitude: longitude,
            name: locationName,
            source: MemoryLocationSource(rawValue: locationSourceRawValue ?? "") ?? .manualPin
        )
    }

    var locationCandidates: [MemoryLocationCandidate] {
        get {
            guard let locationCandidatesData else { return [] }
            return (try? JSONDecoder().decode([MemoryLocationCandidate].self, from: locationCandidatesData)) ?? []
        }
        set {
            locationCandidatesData = try? JSONEncoder().encode(newValue)
        }
    }

    var isRecentlyDeleted: Bool {
        deletedAt != nil
    }

    func setLocation(latitude: Double, longitude: Double, name: String? = nil) {
        setLocation(MemoryLocation(latitude: latitude, longitude: longitude, name: name))
    }

    func setLocation(_ location: MemoryLocation) {
        latitude = location.latitude
        longitude = location.longitude
        locationName = location.name
        locationSourceRawValue = location.source.rawValue
    }

    func clearLocation() {
        latitude = nil
        longitude = nil
        locationName = nil
        locationSourceRawValue = nil
    }

    func moveToRecentlyDeleted(at date: Date = Date(), batchID: UUID = UUID()) {
        deletedAt = date
        deletionBatchID = batchID
        modifiedAt = date
    }

    func restoreFromRecentlyDeleted(at date: Date = Date()) {
        deletedAt = nil
        deletionBatchID = nil
        modifiedAt = date
    }
}
