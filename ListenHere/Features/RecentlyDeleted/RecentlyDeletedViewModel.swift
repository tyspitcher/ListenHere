// Loads Recently Deleted items and coordinates recovery, permanent deletion, and expiry cleanup.
import Foundation
import Observation

@MainActor
@Observable
final class RecentlyDeletedViewModel {
    private(set) var items: [RecentlyDeletedItem] = []
    private(set) var errorMessage: String?

    private let repository: any RecentlyDeletedRepository
    private let mediaReader: (any ManagedMediaReading)?
    private var memoryThumbnailURLs: [RecentlyDeletedItem.ID: URL] = [:]

    init(
        repository: any RecentlyDeletedRepository,
        mediaReader: (any ManagedMediaReading)? = nil
    ) {
        self.repository = repository
        self.mediaReader = mediaReader
    }

    func load(at referenceDate: Date = Date()) {
        do {
            try repository.purgeExpiredItems(at: referenceDate)
            items = try repository.fetchItems()
            resolveMemoryThumbnailURLs()
            errorMessage = nil
        } catch {
            errorMessage = "Recently Deleted couldn’t be loaded. Please try again."
        }
    }

    func recover(_ item: RecentlyDeletedItem, at date: Date = Date()) {
        do {
            try repository.recover(item.id, at: date)
            items = try repository.fetchItems()
            resolveMemoryThumbnailURLs()
            errorMessage = nil
        } catch {
            errorMessage = "This item couldn’t be recovered. Please try again."
        }
    }

    func permanentlyDelete(_ item: RecentlyDeletedItem) {
        do {
            try repository.permanentlyDelete(item.id)
            items = try repository.fetchItems()
            resolveMemoryThumbnailURLs()
            errorMessage = nil
        } catch {
            errorMessage = "This item couldn’t be permanently deleted. Please try again."
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func thumbnailURL(for item: RecentlyDeletedItem) -> URL? {
        memoryThumbnailURLs[item.id]
    }

    private func resolveMemoryThumbnailURLs() {
        memoryThumbnailURLs = Dictionary(
            uniqueKeysWithValues: items.compactMap { item in
                guard item.kind == .memory,
                      let filename = item.photoFilename,
                      let mediaReader,
                      let url = try? mediaReader.fileURL(for: filename) else {
                    return nil
                }
                return (item.id, url)
            }
        )
    }
}
