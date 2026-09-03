// Enumerates the supported strategies for deleting a journal and handling its memories.

import Foundation

nonisolated enum JournalDeletionStrategy: Equatable, Sendable {
    case moveMemories(toJournalID: UUID)
    case moveContainedMemoriesToRecentlyDeleted
}
