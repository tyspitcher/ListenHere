import Foundation
@testable import ListenHere

@MainActor
final class InMemoryManagedMediaStore: ManagedMediaDeleting, ManagedMediaReading, ManagedMediaStoring {
    private(set) var files: [String: Data] = [:]
    private(set) var deletedFilenames: [Set<String>] = []
    var nextError: (any Error)?

    private var nextSequenceNumber = 0

    func store(
        _ data: Data,
        as kind: ManagedMediaKind,
        preferredFileExtension: String
    ) throws -> ManagedMediaFile {
        if let nextError { throw nextError }

        nextSequenceNumber += 1
        let fileExtension = preferredFileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = "\(kind.directoryName)/test-\(nextSequenceNumber).\(fileExtension)"
        files[filename] = data
        return ManagedMediaFile(filename: filename, kind: kind)
    }

    func deleteManagedFiles(named filenames: Set<String>) throws {
        if let nextError { throw nextError }

        deletedFilenames.append(filenames)
        for filename in filenames {
            files[filename] = nil
        }
    }

    func fileURL(for filename: String) throws -> URL {
        guard files[filename] != nil else { throw InMemoryMediaStoreError.missingFile }
        return URL(filePath: "/in-memory/\(filename)")
    }
}

private enum InMemoryMediaStoreError: Error {
    case missingFile
}
