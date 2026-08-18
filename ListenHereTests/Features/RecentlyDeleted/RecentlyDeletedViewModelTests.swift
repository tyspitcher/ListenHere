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
        viewModel.showActions(for: item)

        viewModel.recoverSelectedItem(at: Date(timeIntervalSince1970: 1_600))

        #expect(repository.recoveredIDs == [item.id])
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.selectedItem == nil)
    }
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
