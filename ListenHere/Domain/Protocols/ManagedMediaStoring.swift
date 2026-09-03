// Defines the boundary for copying external media into private storage and returning relative filenames.

import Foundation

enum ManagedMediaKind: String, CaseIterable, Sendable {
    case photo
    case audio
    case exportedVideo

    var directoryName: String {
        switch self {
        case .photo: "photos"
        case .audio: "audio"
        case .exportedVideo: "exports"
        }
    }
}

struct ManagedMediaFile: Equatable, Sendable {
    let filename: String
    let kind: ManagedMediaKind
}

@MainActor
protocol ManagedMediaStoring {
    /// Stores a copy under ListenHere's private media directory and returns its relative name.
    /// The caller persists only this name, never an external Photos or temporary-file URL.
    func store(
        _ data: Data,
        as kind: ManagedMediaKind,
        preferredFileExtension: String
    ) throws -> ManagedMediaFile
}
