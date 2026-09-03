import Foundation
import Testing
@testable import ListenHere

@MainActor
struct LocalManagedMediaStoreTests {
    @Test("Storing media copies it into a type-specific managed directory")
    func storesPhotoData() throws {
        let rootDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)
        let data = Data("photo bytes".utf8)

        let file = try store.store(data, as: .photo, preferredFileExtension: ".HEIC")

        #expect(file.kind == .photo)
        #expect(file.filename.hasPrefix("photos/"))
        #expect(file.filename.hasSuffix(".heic"))
        #expect(try Data(contentsOf: rootDirectory.appending(path: file.filename)) == data)
    }

    @Test("Empty media data is rejected")
    func rejectsEmptyData() throws {
        let rootDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)

        #expect(throws: LocalManagedMediaStore.StorageError.emptyData) {
            try store.store(Data(), as: .audio, preferredFileExtension: "m4a")
        }
    }

    @Test("Unsafe file extensions are rejected")
    func rejectsUnsafeFileExtension() throws {
        let rootDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)

        #expect(throws: LocalManagedMediaStore.StorageError.invalidFileExtension("../heic")) {
            try store.store(Data("photo".utf8), as: .photo, preferredFileExtension: "../heic")
        }
    }

    @Test("Deleting a stored media file removes its managed copy")
    func deletesStoredMedia() throws {
        let rootDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)
        let file = try store.store(Data("recording".utf8), as: .audio, preferredFileExtension: "m4a")

        try store.deleteManagedFiles(named: [file.filename])

        #expect(FileManager.default.fileExists(atPath: rootDirectory.appending(path: file.filename).path) == false)
    }

    @Test("Resolving a stored file returns its app-managed URL")
    func resolvesManagedFileURL() throws {
        let rootDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)
        let file = try store.store(Data("recording".utf8), as: .audio, preferredFileExtension: "m4a")

        #expect(try store.fileURL(for: file.filename) == rootDirectory.appending(path: file.filename))
    }

    @Test("Media remains immediately readable through the managed-store contract after writing")
    func readsBackStoredMediaImmediately() throws {
        let rootDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)
        let expectedData = Data("photo bytes".utf8)

        let file = try store.store(expectedData, as: .photo, preferredFileExtension: "heic")
        let resolvedURL = try store.fileURL(for: file.filename)

        #expect(try Data(contentsOf: resolvedURL) == expectedData)
    }

    @Test("A directory-style managed root resolves and deletes media")
    func managesMediaWithDirectoryStyleRootURL() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appending(path: "ListenHereMediaStore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }
        let store = LocalManagedMediaStore(rootDirectory: rootDirectory)
        let file = try store.store(Data("photo bytes".utf8), as: .photo, preferredFileExtension: "heic")

        let resolvedURL = try store.fileURL(for: file.filename)
        #expect(try Data(contentsOf: resolvedURL) == Data("photo bytes".utf8))

        try store.deleteManagedFiles(named: [file.filename])
        #expect(FileManager.default.fileExists(atPath: resolvedURL.path) == false)
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ListenHereMediaStore-\(UUID().uuidString)")
    }
}
