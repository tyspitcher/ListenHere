// Defines the media-export boundary used before sharing a photo-and-sound memory.

import Foundation

protocol MemoryVideoExporting {
    /// Produces a temporary shareable movie; callers must remove it after sharing finishes.
    nonisolated func exportVideo(
        photoURL: URL,
        audioURL: URL,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL

    func discardTemporaryExport(at url: URL)
}
