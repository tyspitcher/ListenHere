import Foundation

struct MemoryDraft: Equatable, Sendable {
    struct Location: Equatable, Sendable {
        var latitude: Double
        var longitude: Double
        var name: String?
    }

    struct PhotoEdits: Equatable, Sendable {
        var filterIdentifier: String?
        var filterIntensity: Double = 1
        var cropOriginX: Double = 0
        var cropOriginY: Double = 0
        var cropWidth: Double = 1
        var cropHeight: Double = 1
        var rotationDegrees: Double = 0
    }

    struct AudioEdits: Equatable, Sendable {
        var trimStartSeconds: Double = 0
        var trimEndSeconds: Double?
        var isLoopingEnabled: Bool = false
        var crossfadeDurationSeconds: Double = 0
    }

    struct Presentation: Equatable, Sendable {
        var borderStyleIdentifier: String = "instantPhoto"
        var typographyStyleIdentifier: String = "system"
    }

    struct Decoration: Equatable, Identifiable, Sendable {
        var id: UUID = UUID()
        var assetIdentifier: String
        var normalizedX: Double = 0.5
        var normalizedY: Double = 0.5
        var scale: Double = 1
        var rotationDegrees: Double = 0
        var zIndex: Int = 0
    }

    var id: UUID = UUID()
    var capturedAt: Date = Date()
    var title: String?
    var caption: String?
    var photoFilename: String?
    var audioFilename: String?
    var audioDurationSeconds: Double?
    var location: Location?
    var journalIDs: Set<UUID> = []
    var photoEdits: PhotoEdits?
    var audioEdits: AudioEdits?
    var presentation: Presentation?
    var decorations: [Decoration] = []

    func validate() throws {
        guard Self.trimmed(photoFilename) != nil || Self.trimmed(audioFilename) != nil else {
            throw MemoryDraftValidationError.missingMedia
        }

        if let audioDurationSeconds, audioDurationSeconds <= 0 {
            throw MemoryDraftValidationError.invalidAudioDuration
        }

        if let location,
           (-90...90).contains(location.latitude) == false
            || (-180...180).contains(location.longitude) == false {
            throw MemoryDraftValidationError.invalidLocation
        }

        if let edits = photoEdits {
            let cropIsValid = edits.cropOriginX >= 0
                && edits.cropOriginY >= 0
                && edits.cropWidth > 0
                && edits.cropHeight > 0
                && edits.cropOriginX + edits.cropWidth <= 1
                && edits.cropOriginY + edits.cropHeight <= 1
            guard cropIsValid, (0...1).contains(edits.filterIntensity) else {
                throw MemoryDraftValidationError.invalidPhotoEdits
            }
        }

        if let edits = audioEdits {
            let endIsValid = edits.trimEndSeconds.map { $0 > edits.trimStartSeconds } ?? true
            guard edits.trimStartSeconds >= 0,
                  edits.crossfadeDurationSeconds >= 0,
                  endIsValid else {
                throw MemoryDraftValidationError.invalidAudioEdits
            }
        }

        for decoration in decorations {
            guard Self.trimmed(decoration.assetIdentifier) != nil,
                  (0...1).contains(decoration.normalizedX),
                  (0...1).contains(decoration.normalizedY),
                  decoration.scale > 0 else {
                throw MemoryDraftValidationError.invalidDecoration
            }
        }
    }

    var normalizedTitle: String? { Self.trimmed(title) }
    var normalizedCaption: String? { Self.trimmed(caption) }
    var normalizedPhotoFilename: String? { Self.trimmed(photoFilename) }
    var normalizedAudioFilename: String? { Self.trimmed(audioFilename) }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

enum MemoryDraftValidationError: Error, Equatable {
    case missingMedia
    case invalidAudioDuration
    case invalidLocation
    case invalidPhotoEdits
    case invalidAudioEdits
    case invalidDecoration
}
