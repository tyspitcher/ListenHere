import Foundation
import Testing
@testable import ListenHere

struct AppRouterTests {
    @Test("A valid stable path is restored")
    @MainActor
    func restoresValidPath() async {
        let memory = makeMemory()
        let store = NavigationStateStoreStub(path: [.library, .memory(memory.id)])
        let router = AppRouter(
            stateStore: store,
            memoryRepository: RouterMemoryRepository(memory: memory),
            journalRepository: RouterJournalRepository(journals: [])
        )

        await router.restorePathIfNeeded()

        #expect(router.path == [.library, .memory(memory.id)])
    }

    @Test("An invalid model route falls back to All Memories")
    @MainActor
    func invalidRouteFallsBackToRoot() async {
        let store = NavigationStateStoreStub(path: [.memory(UUID())])
        let router = AppRouter(
            stateStore: store,
            memoryRepository: RouterMemoryRepository(memory: nil),
            journalRepository: RouterJournalRepository(journals: [])
        )

        await router.restorePathIfNeeded()

        #expect(router.path.isEmpty)
        #expect(store.savedPaths.last == [])
    }

    private func makeMemory() -> MemorySummary {
        MemorySummary(
            id: UUID(),
            title: "Park",
            caption: nil,
            capturedAt: .init(timeIntervalSince1970: 1),
            thumbnail: nil,
            hasAudio: false,
            audioDurationSeconds: nil,
            locationName: nil,
            journalNames: []
        )
    }
}

@MainActor
private final class NavigationStateStoreStub: NavigationStateStore {
    let path: [AppRoute]
    private(set) var savedPaths: [[AppRoute]] = []

    init(path: [AppRoute]) {
        self.path = path
    }

    func loadPath() -> [AppRoute] { path }
    func savePath(_ path: [AppRoute]) { savedPaths.append(path) }
}

@MainActor
private final class RouterMemoryRepository: MemoryRepository {
    let memory: MemorySummary?

    init(memory: MemorySummary?) {
        self.memory = memory
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { memory.map { [$0] } ?? [] }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? {
        memory?.id == id ? memory : nil
    }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw RouterTestError.unavailable
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw RouterTestError.unavailable
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw RouterTestError.unavailable
    }
}

@MainActor
private final class RouterJournalRepository: JournalRepository {
    let journals: [JournalSummary]

    init(journals: [JournalSummary]) {
        self.journals = journals
    }

    func fetchActiveJournals() async throws -> [JournalSummary] { journals }
    func createJournal(name: String, at date: Date) throws -> Journal {
        throw RouterTestError.unavailable
    }
    func renameJournal(id: UUID, name: String, at date: Date) throws {
        throw RouterTestError.unavailable
    }
    func setDefaultJournal(id: UUID, at date: Date) throws {
        throw RouterTestError.unavailable
    }
    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws {
        throw RouterTestError.unavailable
    }
}

private enum RouterTestError: Error {
    case unavailable
}
