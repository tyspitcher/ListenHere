// Represents the user-visible audio playback states for one memory detail screen.

import Foundation

enum AudioPlaybackState: Equatable {
    case unavailable
    case ready(duration: TimeInterval?)
    case playing(elapsed: TimeInterval, duration: TimeInterval)
    case paused(elapsed: TimeInterval, duration: TimeInterval)
    case failed
}
