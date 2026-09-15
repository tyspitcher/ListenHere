// Defines the operations available in each memory-detail context.

import Foundation

enum MemoryDetailAccess: Equatable, Sendable {
    case active
    case recentlyDeleted

    var permitsEditing: Bool {
        self == .active
    }

    var isRecentlyDeleted: Bool {
        self == .recentlyDeleted
    }
}
