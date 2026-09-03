// Provides the Library hub that links to journals, places, and Recently Deleted.
import SwiftUI

struct LibraryView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        List {
            Section("Browse") {
                NavigationLink(value: AppRoute.journals) {
                    Label {
                        Text("Journals")
                    } icon: {
                        Image(systemName: "books.vertical")
                            .foregroundStyle(palette.accent)
                    }
                }
                NavigationLink(value: AppRoute.places) {
                    Label {
                        Text("Places")
                    } icon: {
                        Image(systemName: "map")
                            .foregroundStyle(palette.secondaryAccent)
                    }
                }
            }

            Section("Manage") {
                NavigationLink(value: AppRoute.recentlyDeleted) {
                    Label {
                        Text("Recently Deleted")
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(palette.tertiaryAccent)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Library")
        .appScreenBackground()
    }
}
