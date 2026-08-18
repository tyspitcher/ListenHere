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

    var kind: Kind {
        id.kind
    }
}
