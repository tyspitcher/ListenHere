// Defines listing, recovery, permanent deletion, and expiry maintenance for Recently Deleted.

import Foundation

protocol RecentlyDeletedRepository: RecentlyDeletedRecovering {
    func fetchItems() throws -> [RecentlyDeletedItem]
    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws
    func purgeExpiredItems(at referenceDate: Date) throws
}
