import Foundation
import Testing
@testable import ListenHere

struct RecentlyDeletedViewModelTests {
    @Test("Recover removes the selected item and refreshes the list")
    @MainActor
    func recoverSelectedItem() {
        let item = RecentlyDeletedItem(
            id: .init(kind: .memory, modelID: UUID()),
            title: "Park",
            deletedAt: Date(timeIntervalSince1970: 1_000),
            expiresAt: Date(timeIntervalSince1970: 2_000)
        )
        let repository = RecentlyDeletedRepositoryStub(items: [item])
        let viewModel = RecentlyDeletedViewModel(repository: repository)
        viewModel.load(at: Date(timeIntervalSince1970: 1_500))
        viewModel.recover(item, at: Date(timeIntervalSince1970: 1_600))

        #expect(repository.recoveredIDs == [item.id])
        #expect(viewModel.items.isEmpty)
    }

    @Test("Deleted memory thumbnails resolve only through the managed-media boundary")
    @MainActor
    func resolvesMemoryThumbnail() {
        let item = RecentlyDeletedItem(
            id: .init(kind: .memory, modelID: UUID()),
            title: "Park",
            deletedAt: Date(timeIntervalSince1970: 1_000),
            expiresAt: Date(timeIntervalSince1970: 2_000),
            photoFilename: "photos/park.heic"
        )
        let photoURL = URL(filePath: "/managed/photos/park.heic")
        let viewModel = RecentlyDeletedViewModel(
            repository: RecentlyDeletedRepositoryStub(items: [item]),
            mediaReader: RecentlyDeletedMediaReaderStub(urls: ["photos/park.heic": photoURL])
        )

        viewModel.load(at: Date(timeIntervalSince1970: 1_500))

        #expect(viewModel.thumbnailURL(for: item) == photoURL)
    }
}

@MainActor
private final class RecentlyDeletedMediaReaderStub: ManagedMediaReading {
    private let urls: [String: URL]

    init(urls: [String: URL]) {
        self.urls = urls
    }

    func fileURL(for filename: String) throws -> URL {
        guard let url = urls[filename] else { throw RecentlyDeletedMediaReaderError.missingFile }
        return url
    }
}

private enum RecentlyDeletedMediaReaderError: Error {
    case missingFile
}

@MainActor
private final class RecentlyDeletedRepositoryStub: RecentlyDeletedRepository {
    var items: [RecentlyDeletedItem]
    private(set) var recoveredIDs: [RecentlyDeletedItem.ID] = []

    init(items: [RecentlyDeletedItem]) {
        self.items = items
    }

    func fetchItems() throws -> [RecentlyDeletedItem] {
        items
    }

    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws {
        recoveredIDs.append(itemID)
        items.removeAll { $0.id == itemID }
    }

    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws {
        items.removeAll { $0.id == itemID }
    }

    func purgeExpiredItems(at referenceDate: Date) throws {}
}
