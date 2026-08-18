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
    let audioDurationSeconds: Double?
    let locationName: String?
    let journalNames: [String]
}
