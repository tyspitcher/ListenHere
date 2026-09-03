// Defines the narrow capability for deleting files owned by ListenHere's managed media store.

@MainActor
protocol ManagedMediaDeleting {
    func deleteManagedFiles(named filenames: Set<String>) throws
}
