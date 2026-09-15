// Defines the operations available while browsing an active or recently deleted journal.

import Foundation

enum JournalDetailAccess: Equatable, Sendable {
    case active
    case recentlyDeleted

    var permitsEditing: Bool {
        self == .active
    }
}
