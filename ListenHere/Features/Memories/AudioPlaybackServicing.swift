// Defines the playback capability Memory Detail needs without exposing AVFoundation to the view model.

import Foundation

@MainActor
protocol AudioPlaybackServicing {
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }

    func loadAudio(at url: URL) async throws
    func play() throws
    func pause()
    func stop() async
}
