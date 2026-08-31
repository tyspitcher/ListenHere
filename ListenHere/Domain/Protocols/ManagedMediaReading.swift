// Resolves a private managed-media filename to an app-owned local URL for presentation services.

import Foundation

@MainActor
protocol ManagedMediaReading {
    func fileURL(for filename: String) throws -> URL
}
