// Defines asynchronous waveform extraction for app-managed audio files.

import Foundation

protocol AudioWaveformAnalyzing: Sendable {
    nonisolated func samples(for url: URL, targetCount: Int) async throws -> [Double]
}
