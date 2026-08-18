import Foundation

enum AppRoute: Codable, Hashable, Sendable {
    case library
    case journals
    case journal(UUID)
    case places
    case recentlyDeleted
    case memory(UUID)
}
