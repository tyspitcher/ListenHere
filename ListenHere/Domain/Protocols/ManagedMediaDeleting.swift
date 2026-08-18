@MainActor
protocol ManagedMediaDeleting {
    func deleteManagedFiles(named filenames: Set<String>) throws
}
