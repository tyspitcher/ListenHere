// Describes how the sharing flow will handle the media currently attached to a memory.

import Foundation

enum MemorySharingAvailability: Equatable, Identifiable, Sendable {
    case photo
    case audio
    case photoAndAudio
    case unavailable

    var id: String {
        switch self {
        case .photo:
            "photo"
        case .audio:
            "audio"
        case .photoAndAudio:
            "photo-and-audio"
        case .unavailable:
            "unavailable"
        }
    }
}
