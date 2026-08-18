import Foundation

enum RecentlyDeletedPolicy {
    static let retentionInterval: TimeInterval = 30 * 24 * 60 * 60

    static func expirationDate(for deletionDate: Date) -> Date {
        deletionDate.addingTimeInterval(retentionInterval)
    }

    static func cutoffDate(relativeTo referenceDate: Date) -> Date {
        referenceDate.addingTimeInterval(-retentionInterval)
    }
}
