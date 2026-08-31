// Defines typed persistence failures that repositories can translate into recoverable feature states.

import Foundation

enum ListenHerePersistenceError: Error, Equatable {
    case memoryNotFound
    case journalNotFound
    case invalidJournalDestination
    case protectedJournal
    case emptyJournalName
    case invalidDraft(MemoryDraftValidationError)
}
