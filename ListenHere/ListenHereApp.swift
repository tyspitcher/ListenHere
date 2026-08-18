//
//  ListenHereApp.swift
//  ListenHere
//
//  Created by Tyson Pitcher on 7/21/26.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct ListenHereApp: App {
    private static let logger = Logger(
        subsystem: "com.tysonpitcher.ListenHere",
        category: "RecentlyDeleted"
    )

    private let sharedModelContainer: ModelContainer
    private let appContainer: AppContainer

    init() {
        let container = Self.makeModelContainer()
        sharedModelContainer = container

        let applicationSupport: URL
        do {
            applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            fatalError("Could not locate Application Support: \(error)")
        }
        let mediaStore = LocalManagedMediaStore(
            rootDirectory: applicationSupport.appending(path: "Media", directoryHint: .isDirectory)
        )
        let memoryRepository = SwiftDataMemoryRepository(modelContext: container.mainContext)
        let journalRepository = SwiftDataJournalRepository(modelContext: container.mainContext)
        let recentlyDeletedRepository = SwiftDataRecentlyDeletedRepository(
            modelContext: container.mainContext,
            mediaStore: mediaStore
        )
        appContainer = AppContainer(
            memoryRepository: memoryRepository,
            journalRepository: journalRepository,
            recentlyDeletedRepository: recentlyDeletedRepository
        )

        do {
            try recentlyDeletedRepository.purgeExpiredItems(at: Date())
        } catch {
            Self.logger.error("Recently Deleted maintenance failed.")
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: ListenHereSchemaV1.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ListenHereMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: appContainer)
        }
        .modelContainer(sharedModelContainer)
    }
}
