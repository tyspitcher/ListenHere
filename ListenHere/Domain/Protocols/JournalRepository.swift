// Defines the journal persistence capabilities required by features and their test doubles.

import Foundation

@MainActor
protocol JournalRepository {
    func fetchActiveJournals() async throws -> [JournalSummary]
    func createJournal(name: String, at date: Date) throws -> Journal
    func renameJournal(id: UUID, name: String, at date: Date) throws
    func setDefaultJournal(id: UUID, at date: Date) throws
    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws
}
