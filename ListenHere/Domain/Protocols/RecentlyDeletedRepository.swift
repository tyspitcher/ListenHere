// Defines listing, recovery, permanent deletion, and expiry maintenance for Recently Deleted.

import Foundation

@MainActor
protocol RecentlyDeletedRepository {
    func fetchItems() throws -> [RecentlyDeletedItem]
    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws
    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws
    func purgeExpiredItems(at referenceDate: Date) throws
}
