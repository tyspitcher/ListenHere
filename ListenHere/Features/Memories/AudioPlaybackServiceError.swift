// Describes recoverable playback-service failures for presentation-level handling.

import Foundation

enum AudioPlaybackServiceError: Error {
    case audioNotLoaded
    case couldNotStart
}
