// Renders deleted journals and memories with native recovery and permanent-deletion actions.
import SwiftUI

struct RecentlyDeletedView: View {
    @State private var viewModel: RecentlyDeletedViewModel

    init(viewModel: RecentlyDeletedViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Recently Deleted Items",
                    systemImage: "trash",
                    description: Text("Deleted memories and journals remain here for 30 days.")
                )
            } else {
                List(viewModel.items) { item in
                    RecentlyDeletedRow(item: item) {
                        viewModel.showActions(for: item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Recently Deleted")
        .task {
            viewModel.load()
        }
        .confirmationDialog(
            viewModel.selectedItem?.title ?? "Recently Deleted Item",
            isPresented: actionsArePresented,
            presenting: viewModel.selectedItem
        ) { _ in
            Button("Recover") {
                viewModel.recoverSelectedItem()
            }
            Button("Delete Permanently", role: .destructive) {
                viewModel.permanentlyDeleteSelectedItem()
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissActions()
            }
        } message: { _ in
            Text("Choose whether to recover this item or delete it permanently.")
        }
        .alert("Something Went Wrong", isPresented: errorIsPresented) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
    }

    private var actionsArePresented: Binding<Bool> {
        Binding(
            get: { viewModel.selectedItem != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.dismissActions()
                }
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.dismissError()
                }
            }
        )
    }
}

private struct RecentlyDeletedRow: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let item: RecentlyDeletedItem
    let showActions: () -> Void

    var body: some View {
        let palette = theme.palette(for: colorScheme)

        HStack(spacing: 12) {
            Image(systemName: item.kind == .memory ? "photo.on.rectangle" : "book.closed")
                .foregroundStyle(palette.tertiaryAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text("Deletes \(item.expiresAt, style: .relative)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: showActions) {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Actions for \(item.title)")
            .accessibilityHint("Recover or permanently delete this item")
        }
    }
}

#Preview {
    let now = Date()
    let repository = PreviewRecentlyDeletedRepository(items: [
        RecentlyDeletedItem(
            id: .init(kind: .memory, modelID: UUID()),
            title: "A Day at the Park",
            deletedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            expiresAt: now.addingTimeInterval(28 * 24 * 60 * 60)
        ),
        RecentlyDeletedItem(
            id: .init(kind: .journal, modelID: UUID()),
            title: "Summer Trip",
            deletedAt: now.addingTimeInterval(-5 * 24 * 60 * 60),
            expiresAt: now.addingTimeInterval(25 * 24 * 60 * 60)
        ),
    ])

    NavigationStack {
        RecentlyDeletedView(
            viewModel: RecentlyDeletedViewModel(repository: repository)
        )
    }
}

@MainActor
private final class PreviewRecentlyDeletedRepository: RecentlyDeletedRepository {
    private var items: [RecentlyDeletedItem]

    init(items: [RecentlyDeletedItem]) {
        self.items = items
    }

    func fetchItems() throws -> [RecentlyDeletedItem] {
        items
    }

    func recover(_ itemID: RecentlyDeletedItem.ID, at date: Date) throws {
        items.removeAll { $0.id == itemID }
    }

    func permanentlyDelete(_ itemID: RecentlyDeletedItem.ID) throws {
        items.removeAll { $0.id == itemID }
    }

    func purgeExpiredItems(at referenceDate: Date) throws {
        items.removeAll { $0.expiresAt <= referenceDate }
    }
}
