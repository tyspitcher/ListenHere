// Hosts the root NavigationStack, applies the selected theme, and maps routes to feature views.
// It is the SwiftUI composition point for the app shell.
//
//  ContentView.swift
//  ListenHere
//
//  Created by Tyson Pitcher on 7/21/26.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("ListenHere.themeID") private var themeIDRawValue = ThemeID.listenHere.rawValue

    var body: some View {
        @Bindable var router = container.router

        NavigationStack(path: $router.path) {
            AllMemoriesView(
                viewModel: container.allMemoriesViewModel,
                openLibrary: { router.push(.library) },
                openMemory: { container.router.push(.memory($0)) },
                makeCaptureViewModel: {
                    container.makeCaptureViewModel(origin: .allMemories)
                },
                makeVoiceRecordingViewModel: { captureViewModel in
                    container.makeVoiceRecordingViewModel(captureViewModel: captureViewModel)
                },
                makeCaptureMediaPreviewViewModel: { captureViewModel in
                    container.makeCaptureMediaPreviewViewModel(captureViewModel: captureViewModel)
                },
                makeCameraCaptureViewModel: container.makeCameraCaptureViewModel,
                makeMemoryEditSession: container.makeMemoryEditSession,
                makeMemoryJournalAssignmentViewModel: container.makeMemoryJournalAssignmentViewModel,
                makeVoiceRecordingViewModelForEditing: { editSession in
                    container.makeVoiceRecordingViewModel(editSession: editSession)
                },
                makeLocationPickerViewModel: container.makeLocationPickerViewModel
            )
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .appScreenBackground()
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
            LibraryView()
        case .journals:
            JournalsView(viewModel: container.makeJournalsViewModel())
        case .journal(let id):
            MemoryListView(
                viewModel: container.makeJournalDetailViewModel(journalID: id),
                openMemory: { container.router.push(.memory($0)) },
                makeCaptureViewModel: {
                    container.makeCaptureViewModel(origin: .journal(id))
                },
                makeVoiceRecordingViewModel: { captureViewModel in
                    container.makeVoiceRecordingViewModel(captureViewModel: captureViewModel)
                },
                makeCaptureMediaPreviewViewModel: { captureViewModel in
                    container.makeCaptureMediaPreviewViewModel(captureViewModel: captureViewModel)
                },
                makeCameraCaptureViewModel: container.makeCameraCaptureViewModel,
                makeMemoryEditSession: container.makeMemoryEditSession,
                makeMemoryJournalAssignmentViewModel: container.makeMemoryJournalAssignmentViewModel,
                makeVoiceRecordingViewModelForEditing: { editSession in
                    container.makeVoiceRecordingViewModel(editSession: editSession)
                },
                makeLocationPickerViewModel: container.makeLocationPickerViewModel
            )
        case .places:
            PlacesView(
                viewModel: container.makePlacesViewModel(),
                openMemory: { container.router.push(.memory($0)) }
            )
        case .recentlyDeleted:
            RecentlyDeletedView(viewModel: container.makeRecentlyDeletedViewModel())
        case .memory(let id):
            MemoryDetailView(
                viewModel: container.makeMemoryDetailViewModel(memoryID: id),
                makeVoiceRecordingViewModel: { editSession in
                    container.makeVoiceRecordingViewModel(editSession: editSession)
                },
                makeLocationPickerViewModel: container.makeLocationPickerViewModel
            )
        }
    }
}

#if DEBUG
#Preview {
    let memoryRepository = PreviewMemoryRepository()
    let journalRepository = PreviewJournalRepository()
    let recentlyDeletedRepository = PreviewRecentlyDeletedRepository()
    let mediaStore = PreviewManagedMediaStore()
    ContentView()
        .environment(
            AppContainer(
                memoryRepository: memoryRepository,
                journalRepository: journalRepository,
                recentlyDeletedRepository: recentlyDeletedRepository,
                mediaStore: mediaStore,
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

    func renameJournal(id: UUID, name: String, at date: Date) throws {
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
