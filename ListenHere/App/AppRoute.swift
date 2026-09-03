// Defines the stable value-based destinations used by the app's navigation stack.

import Foundation

enum AppRoute: Codable, Hashable, Sendable {
    case library
    case journals
    case journal(UUID)
    case places
    case recentlyDeleted
    case memory(UUID)
}
