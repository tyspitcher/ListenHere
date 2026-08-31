// Owns app-level navigation state, restores valid browsing routes, and falls back safely.

import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = [] {
        didSet { stateStore.savePath(path) }
    }

    private let stateStore: any NavigationStateStore
    private let memoryRepository: any MemoryRepository
    private let journalRepository: any JournalRepository
    private var hasRestored = false

    init(
        stateStore: any NavigationStateStore,
        memoryRepository: any MemoryRepository,
        journalRepository: any JournalRepository
    ) {
        self.stateStore = stateStore
        self.memoryRepository = memoryRepository
        self.journalRepository = journalRepository
    }

    func restorePathIfNeeded() async {
        guard hasRestored == false else { return }
        hasRestored = true

        let storedPath = stateStore.loadPath()
        let activeJournalIDs = (try? await journalRepository.fetchActiveJournals())
            .map { Set($0.map(\.id)) } ?? []
        var validatedPath: [AppRoute] = []

        for route in storedPath {
            switch route {
            case .memory(let id):
                guard (try? await memoryRepository.fetchActiveMemory(id: id)) != nil else {
                    path = []
                    return
                }
            case .journal(let id):
                guard activeJournalIDs.contains(id) else {
                    path = []
                    return
                }
            case .library, .journals, .places, .recentlyDeleted:
                break
            }
            validatedPath.append(route)
        }
        path = validatedPath
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }
}
