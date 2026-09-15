// Defines the single recovery capability needed by read-only deleted-memory detail screens.

import Foundation

@MainActor
protocol RecentlyDeletedRecovering {
    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws
}
