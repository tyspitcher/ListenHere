import Foundation

struct LocalManagedMediaStore: ManagedMediaDeleting {
    enum StorageError: Error {
        case invalidFilename(String)
    }

    private let rootDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.fileManager = fileManager
    }

    func deleteManagedFiles(named filenames: Set<String>) throws {
        for filename in filenames {
            let fileURL = rootDirectory.appending(path: filename).standardizedFileURL
            let rootPath = rootDirectory.path(percentEncoded: false) + "/"

            guard fileURL.path(percentEncoded: false).hasPrefix(rootPath) else {
                throw StorageError.invalidFilename(filename)
            }

            if fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
}
