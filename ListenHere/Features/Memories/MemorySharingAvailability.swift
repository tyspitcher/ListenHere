// Describes how the sharing flow will handle the media currently attached to a memory.

import Foundation

enum MemorySharingAvailability: Equatable, Identifiable, Sendable {
    case photo
    case video
    case needsBackground
    case unavailable

    var id: String {
        switch self {
        case .photo:
            "photo"
        case .video:
            "video"
        case .needsBackground:
            "needs-background"
        case .unavailable:
            "unavailable"
        }
    }
}
