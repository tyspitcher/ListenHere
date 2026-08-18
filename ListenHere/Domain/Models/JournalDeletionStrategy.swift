import Foundation

enum JournalDeletionStrategy: Equatable, Sendable {
    case moveMemories(toJournalID: UUID)
    case moveContainedMemoriesToRecentlyDeleted
}
