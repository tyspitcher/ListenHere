// Loads Recently Deleted items and coordinates recovery, permanent deletion, and expiry cleanup.
import Foundation
import Observation

@MainActor
@Observable
final class RecentlyDeletedViewModel {
    private(set) var items: [RecentlyDeletedItem] = []
    private(set) var errorMessage: String?
    var selectedItem: RecentlyDeletedItem?

    private let repository: any RecentlyDeletedRepository

    init(repository: any RecentlyDeletedRepository) {
        self.repository = repository
    }

    func load(at referenceDate: Date = Date()) {
        do {
            try repository.purgeExpiredItems(at: referenceDate)
            items = try repository.fetchItems()
            errorMessage = nil
        } catch {
            errorMessage = "Recently Deleted couldn’t be loaded. Please try again."
        }
    }

    func showActions(for item: RecentlyDeletedItem) {
        selectedItem = item
    }

    func dismissActions() {
        selectedItem = nil
    }

    func recoverSelectedItem(at date: Date = Date()) {
        guard let selectedItem else {
            return
        }

        do {
            try repository.recover(selectedItem.id, at: date)
            self.selectedItem = nil
            items = try repository.fetchItems()
            errorMessage = nil
        } catch {
            errorMessage = "This item couldn’t be recovered. Please try again."
        }
    }

    func permanentlyDeleteSelectedItem() {
        guard let selectedItem else {
            return
        }

        do {
            try repository.permanentlyDelete(selectedItem.id)
            self.selectedItem = nil
            items = try repository.fetchItems()
            errorMessage = nil
        } catch {
            errorMessage = "This item couldn’t be permanently deleted. Please try again."
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
