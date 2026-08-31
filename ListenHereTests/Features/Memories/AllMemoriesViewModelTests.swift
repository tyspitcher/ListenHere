import Foundation
import Testing
@testable import ListenHere

struct AllMemoriesViewModelTests {
    @Test("Loading maps repository memories into loaded state")
    @MainActor
    func loadSuccess() async {
        let memory = makeSummary(id: UUID(), title: "Park")
        let repository = MemoryRepositoryStub(result: .success([memory]))
        let viewModel = AllMemoriesViewModel(repository: repository)

        viewModel.load()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.state == .loaded([memory]))
    }

    @Test("A repository error produces a retryable failure state")
    @MainActor
    func loadFailure() async {
        let repository = MemoryRepositoryStub(result: .failure(TestError.failed))
        let viewModel = AllMemoriesViewModel(repository: repository)

        viewModel.load()
        await Task.yield()
        await Task.yield()

        guard case .failed = viewModel.state else {
            Issue.record("Expected a failed state")
            return
        }
    }

    @Test("A cancelled load cannot overwrite a newer result")
    @MainActor
    func staleLoadDoesNotOverwriteNewerState() async {
        let repository = ControlledMemoryRepository()
        let viewModel = AllMemoriesViewModel(repository: repository)
        let oldMemory = makeSummary(id: UUID(), title: "Old")
        let newMemory = makeSummary(id: UUID(), title: "New")

        viewModel.load()
        await repository.waitForRequestCount(1)
        viewModel.load()
        await repository.waitForRequestCount(2)

        repository.resolveRequest(at: 1, with: .success([newMemory]))
        await Task.yield()
        repository.resolveRequest(at: 0, with: .success([oldMemory]))
        await Task.yield()
        await Task.yield()

        #expect(viewModel.state == .loaded([newMemory]))
    }

    @Test("Loading resolves an existing managed photo for card presentation")
    @MainActor
    func loadResolvesManagedPhotoURL() async throws {
        let mediaStore = InMemoryManagedMediaStore()
        let file = try mediaStore.store(Data("photo".utf8), as: .photo, preferredFileExtension: "heic")
        let memory = MemorySummary(
            id: UUID(),
            title: "Park",
            caption: nil,
            capturedAt: .init(timeIntervalSince1970: 1),
            thumbnail: .managedFile(file.filename),
            hasAudio: false,
            audioDurationSeconds: nil,
            locationName: nil,
            journalNames: []
        )
        let viewModel = AllMemoriesViewModel(
            repository: MemoryRepositoryStub(result: .success([memory])),
            mediaReader: mediaStore
        )

        viewModel.load()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.managedPhotoURL(for: memory) == URL(filePath: "/in-memory/\(file.filename)"))
    }

    private func makeSummary(id: UUID, title: String) -> MemorySummary {
        MemorySummary(
            id: id,
            title: title,
            caption: nil,
            capturedAt: .init(timeIntervalSince1970: 1),
            thumbnail: nil,
            hasAudio: true,
            audioDurationSeconds: 10,
            locationName: nil,
            journalNames: []
        )
    }
}

@MainActor
private final class MemoryRepositoryStub: MemoryRepository {
    let result: Result<[MemorySummary], Error>

    init(result: Result<[MemorySummary], Error>) {
        self.result = result
    }

    func fetchActiveMemories() async throws -> [MemorySummary] { try result.get() }
    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { try result.get() }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? {
        try result.get().first(where: { $0.id == id })
    }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw TestError.failed
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw TestError.failed
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw TestError.failed
    }
}

private enum TestError: Error {
    case failed
}

@MainActor
private final class ControlledMemoryRepository: MemoryRepository {
    private var continuations: [CheckedContinuation<[MemorySummary], Error>?] = []

    func fetchActiveMemories() async throws -> [MemorySummary] {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while continuations.count < count {
            await Task.yield()
        }
    }

    func resolveRequest(at index: Int, with result: Result<[MemorySummary], Error>) {
        guard continuations.indices.contains(index), let continuation = continuations[index] else {
            Issue.record("Missing controlled repository request at index \(index)")
            return
        }
        continuations[index] = nil
        continuation.resume(with: result)
    }

    func fetchActiveMemories(journalID: UUID) async throws -> [MemorySummary] { [] }
    func fetchActiveMemory(id: UUID) async throws -> MemorySummary? { nil }
    func createMemory(from draft: MemoryDraft, origin: MemoryCreationOrigin) throws -> Memory {
        throw TestError.failed
    }
    func updateJournalAssignments(memoryID: UUID, journalIDs: Set<UUID>) throws {
        throw TestError.failed
    }
    func moveToRecentlyDeleted(memoryID: UUID, at date: Date) throws {
        throw TestError.failed
    }
}
