import Foundation

protocol NavigationStateStore: Sendable {
    func loadPath() -> [AppRoute]
    func savePath(_ path: [AppRoute])
}

struct UserDefaultsNavigationStateStore: NavigationStateStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "ListenHere.navigationPath"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadPath() -> [AppRoute] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AppRoute].self, from: data)) ?? []
    }

    func savePath(_ path: [AppRoute]) {
        guard let data = try? JSONEncoder().encode(path) else { return }
        defaults.set(data, forKey: key)
    }
}

struct InMemoryNavigationStateStore: NavigationStateStore {
    private let initialPath: [AppRoute]

    init(initialPath: [AppRoute] = []) {
        self.initialPath = initialPath
    }

    func loadPath() -> [AppRoute] { initialPath }
    func savePath(_ path: [AppRoute]) {}
}
