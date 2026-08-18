//
//  ContentView.swift
//  ListenHere
//
//  Created by Tyson Pitcher on 7/21/26.
//

import SwiftUI

struct ContentView: View {
    @State private var router: AppRouter
    @AppStorage("ListenHere.themeID") private var themeIDRawValue = ThemeID.listenHere.rawValue

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _router = State(wrappedValue: container.router)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            AllMemoriesView(
                viewModel: AllMemoriesViewModel(repository: container.memoryRepository),
                openLibrary: { router.push(.library) },
                openMemory: { router.push(.memory($0)) }
            )
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .appTheme(activeTheme)
        .task { await router.restorePathIfNeeded() }
    }

    private var activeTheme: AppTheme {
        (ThemeID(rawValue: themeIDRawValue) ?? .listenHere).theme
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .library:
            MemoryAtlasView()
        case .journals:
            JournalsView(
                viewModel: JournalsViewModel(repository: container.journalRepository)
            )
        case .journal(let id):
            MemoryListView(
                viewModel: JournalDetailViewModel(
                    journalID: id,
                    repository: container.memoryRepository
                )
            )
        case .places:
            PlacesView()
        case .recentlyDeleted:
            RecentlyDeletedView(
                viewModel: RecentlyDeletedViewModel(
                    repository: container.recentlyDeletedRepository
                )
            )
        case .memory(let id):
            MemoryDetailView(
                viewModel: MemoryDetailViewModel(
                    memoryID: id,
                    repository: container.memoryRepository
                )
            )
        }
    }
}

#if DEBUG
#Preview {
    let memoryRepository = PreviewMemoryRepository()
    let journalRepository = PreviewJournalRepository()
    let recentlyDeletedRepository = PreviewRecentlyDeletedRepository()
    ContentView(
        container: AppContainer(
            memoryRepository: memoryRepository,
            journalRepository: journalRepository,
            recentlyDeletedRepository: recentlyDeletedRepository,
            navigationStateStore: InMemoryNavigationStateStore()
        )
    )
}

@MainActor
private final class PreviewJournalRepository: JournalRepository {
    func fetchActiveJournals() async throws -> [JournalSummary] {
        [
            JournalSummary(
                id: UUID(),
                name: "Nature Sounds",
                memoryCount: 1,
                isDefault: true,
                isSystemUnassigned: false
            ),
        ]
    }

    func createJournal(name: String, at date: Date) throws -> Journal {
        throw PreviewRepositoryError.readOnly
    }

    func setDefaultJournal(id: UUID, at date: Date) throws {
        throw PreviewRepositoryError.readOnly
    }

    func moveToRecentlyDeleted(
        journalID: UUID,
        strategy: JournalDeletionStrategy,
        at date: Date
    ) throws {
        throw PreviewRepositoryError.readOnly
    }
}

@MainActor
private final class PreviewRecentlyDeletedRepository: RecentlyDeletedRepository {
    func fetchItems() throws -> [RecentlyDeletedItem] { [] }
    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws {}
    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws {}
    func purgeExpiredItems(at referenceDate: Date) throws {}
}
#endif
