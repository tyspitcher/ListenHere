// Copies media into ListenHere's private, type-specific directories and safely removes managed files.

import Foundation
import OSLog

struct LocalManagedMediaStore: ManagedMediaDeleting, ManagedMediaReading, ManagedMediaStoring {
    enum StorageError: Error, Equatable {
        case emptyData
        case invalidFileExtension(String)
        case invalidFilename(String)
        case missingFile(String)
    }

    private let rootDirectory: URL
    private let fileManager: FileManager
    private static let logger = Logger(
        subsystem: "com.tysonpitcher.ListenHere",
        category: "ManagedMedia"
    )

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.fileManager = fileManager
    }

    func store(
        _ data: Data,
        as kind: ManagedMediaKind,
        preferredFileExtension: String
    ) throws -> ManagedMediaFile {
        guard data.isEmpty == false else {
            throw StorageError.emptyData
        }

        let fileExtension = try normalizedFileExtension(preferredFileExtension)
        let filename = "\(kind.directoryName)/\(UUID().uuidString.lowercased()).\(fileExtension)"
        let destinationURL = rootDirectory.appending(path: filename)
        // Import a private copy while the source is still accessible; Photos and capture URLs are
        // temporary or externally owned, so they must never become durable Memory references.
        do {
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destinationURL, options: .atomic)
            Self.logger.debug("Managed media write completed.")
        } catch {
            // Do not include filenames, URLs, or media details in logs. They are private content.
            Self.logger.error("Managed media write failed.")
            throw error
        }

        return ManagedMediaFile(filename: filename, kind: kind)
    }

    func deleteManagedFiles(named filenames: Set<String>) throws {
        do {
            for filename in filenames {
                let fileURL = rootDirectory.appending(path: filename).standardizedFileURL
                let rootPath = managedRootPath

                guard fileURL.path(percentEncoded: false).hasPrefix(rootPath) else {
                    throw StorageError.invalidFilename(filename)
                }

                if fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                    try fileManager.removeItem(at: fileURL)
                }
            }
            Self.logger.debug("Managed media removal completed.")
        } catch {
            Self.logger.error("Managed media removal failed.")
            throw error
        }
    }

    func fileURL(for filename: String) throws -> URL {
        let fileURL = rootDirectory.appending(path: filename).standardizedFileURL
        let rootPath = managedRootPath

        do {
            guard fileURL.path(percentEncoded: false).hasPrefix(rootPath) else {
                throw StorageError.invalidFilename(filename)
            }
            guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
                throw StorageError.missingFile(filename)
            }
            Self.logger.debug("Managed media resolution completed.")
            return fileURL
        } catch {
            Self.logger.error("Managed media resolution failed.")
            throw error
        }
    }

    private func normalizedFileExtension(_ rawValue: String) throws -> String {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileExtension = trimmedValue.hasPrefix(".")
            ? String(trimmedValue.dropFirst())
            : trimmedValue
        let permittedCharacters = CharacterSet.alphanumerics

        guard fileExtension.isEmpty == false,
              fileExtension.unicodeScalars.allSatisfy(permittedCharacters.contains) else {
            throw StorageError.invalidFileExtension(rawValue)
        }

        return fileExtension.lowercased()
    }

    /// Application Support is supplied as a directory URL and therefore already ends in `/`.
    /// Preserve exactly one separator so private managed files pass containment validation.
    private var managedRootPath: String {
        let path = rootDirectory.path(percentEncoded: false)
        return path.hasSuffix("/") ? path : path + "/"
    }
}
