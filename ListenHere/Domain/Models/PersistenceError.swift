import Foundation

enum ListenHerePersistenceError: Error, Equatable {
    case memoryNotFound
    case journalNotFound
    case invalidJournalDestination
    case protectedJournal
    case emptyJournalName
    case invalidDraft(MemoryDraftValidationError)
}
