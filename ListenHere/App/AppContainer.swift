import Foundation

@MainActor
final class AppContainer {
    let memoryRepository: any MemoryRepository
    let journalRepository: any JournalRepository
    let recentlyDeletedRepository: any RecentlyDeletedRepository
    let router: AppRouter

    init(
        memoryRepository: any MemoryRepository,
        journalRepository: any JournalRepository,
        recentlyDeletedRepository: any RecentlyDeletedRepository,
        navigationStateStore: (any NavigationStateStore)? = nil
    ) {
        self.memoryRepository = memoryRepository
        self.journalRepository = journalRepository
        self.recentlyDeletedRepository = recentlyDeletedRepository
        router = AppRouter(
            stateStore: navigationStateStore ?? UserDefaultsNavigationStateStore(),
            memoryRepository: memoryRepository,
            journalRepository: journalRepository
        )
    }
}
