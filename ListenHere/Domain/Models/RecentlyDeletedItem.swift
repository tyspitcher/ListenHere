// Represents a deleted journal or memory in the 30-day Recently Deleted presentation.

import Foundation

struct RecentlyDeletedItem: Identifiable, Equatable, Sendable {
    struct ID: Hashable, Sendable {
        let kind: Kind
        let modelID: UUID
    }

    enum Kind: String, Hashable, Sendable {
        case memory
        case journal
    }

    let id: ID
    let title: String
    let deletedAt: Date
    let expiresAt: Date
    /// The app-managed photo filename retained with a deleted memory, if it has one.
    let photoFilename: String?

    init(
        id: ID,
        title: String,
        deletedAt: Date,
        expiresAt: Date,
        photoFilename: String? = nil
    ) {
        self.id = id
        self.title = title
        self.deletedAt = deletedAt
        self.expiresAt = expiresAt
        self.photoFilename = photoFilename
    }

    var kind: Kind {
        id.kind
    }
}
