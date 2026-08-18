import Foundation

@MainActor
protocol MemoryRepository {
    func fetchActiveMemories() async throws -> [MemorySummary]
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary]
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary?
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws
}
